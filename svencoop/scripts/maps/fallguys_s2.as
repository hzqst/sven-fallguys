
const int FL_ONGROUND = (1<<9);
const int FL_BASEVELOCITY = (1<<22);

const int SF_BRUSH_ROTATE_INSTANT = 1;
const int SF_BRUSH_ROTATE_BACKWARDS = 2;
const int SF_BRUSH_ROTATE_Z_AXIS = 4;
const int SF_BRUSH_ROTATE_X_AXIS = 8;
const int SF_BRUSH_ACCDCC = 16;

const int TRAIN_STARTPITCH				= 60;
const int TRAIN_MAXPITCH				= 200;
const int TRAIN_MAXSPEED 				= 1000; // approx max speed for sound pitch calculation
 
const int SF_TRACKTRAIN_NOPITCH			= 1;
const int SF_TRACKTRAIN_NOCONTROL		= 2;
const int SF_TRACKTRAIN_FORWARDONLY		= 4;
const int SF_TRACKTRAIN_PASSABLE		= 8;
const int SF_TRACKTRAIN_KEEPRUNNING		= 16;
const int SF_TRACKTRAIN_STARTOFF		= 32;
const int SF_TRACKTRAIN_KEEPSPEED		= 64; // Don't stop on "disable train" path track

const int SF_TRAIN_WAIT_RETRIGGER	 = 1;
const int SF_TRAIN_START_ON		 = 4;		// Train is initially moving
const int SF_TRAIN_PASSABLE		= 8;

const int SF_CORNER_WAITFORTRIG  = 1;
const int SF_CORNER_TELEPORT = 2;
const int SF_CORNER_FIREONCE = 4;

class CPlayerBlockStateItem
{
	CPlayerBlockStateItem(){
		IsBlocking = false;
		flLastBlockTime = 0;
		flLastSoundTime = 0;
		flStartBlockTime = 0;
	}
	bool IsBlocking;
	float flLastBlockTime;
	float flLastSoundTime;
	float flStartBlockTime;
	string szPlayingSound;
}

array<CPlayerBlockStateItem> g_ArrayBlockPlayer(33);
array<int> g_ArrayGrabPlayer(33);
array<float> g_ArrayBouncePlayer(33);
array<bool> g_ArrayFallingPlayer(33);
array<EHandle> g_ArrayArrowEntityPlayer(33);
array<string> g_ArrayFallingPlayerPlayingSound(33);

array<string> g_szPlayerJumpSound(8);
array<string> g_szPlayerFallingSound(2);

const string g_szPlayerGrabSound = "fallguys/grab.ogg";
const string g_szPlayerGrabReleaseSound = "fallguys/grabrelease.ogg";

const string g_szPlayerArrowSprite = "sprites/fallguys/playerarrow.spr";
const string g_szPlayerArrowSprite2 = "sprites/fallguys/playerarrow2.spr";

const int g_iPlayerArrowSpriteMagicNumber = 1919810;

const int g_iLodStudioModelMagicNumber = 1919811;

int g_iPlayerArrowSpriteModelIndex = 0;
int g_iPlayerArrowSprite2ModelIndex = 0;

class CEnvStudioModel : ScriptBaseEntity
{
	CBaseEntity @m_CopyFromEntity = null;

	void Precache()
	{
		BaseClass.Precache();

		g_Game.PrecacheModel( self.pev.model );
	}

	void Spawn()
	{
		Precache();

		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		self.pev.iuser4 = g_iLodStudioModelMagicNumber;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		if(!string(self.pev.target).IsEmpty())
		{
			self.pev.nextthink = g_Engine.time + 1.5;
			SetThink(ThinkFunction(this.Animate));
		}
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "lod1"){
			self.pev.fuser1 = atof(szValue);
			return true;
		}
		if(szKey == "lod1body"){
			self.pev.iuser1 = atoi(szValue);
			return true;
		}
		if(szKey == "lod2"){
			self.pev.fuser2 = atof(szValue);
			return true;
		}
		if(szKey == "lod2body"){
			self.pev.iuser2 = atoi(szValue);
			return true;
		}
		if(szKey == "lod3"){
			self.pev.fuser3 = atof(szValue);
			return true;
		}
		if(szKey == "lod3body"){
			self.pev.iuser3 = atoi(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Animate()
	{
		//g_Game.AlertMessage( at_console, "Animate %1", string(self.pev.target));

		if(m_CopyFromEntity is null)
		{
			if(string(self.pev.target).IsEmpty())
				return;

			CBaseEntity @pTarget = g_EntityFuncs.FindEntityByTargetname( null, self.pev.target );

			if(pTarget is null)
				return;

			@m_CopyFromEntity = @pTarget;
			self.pev.movetype = MOVETYPE_NOCLIP;
		}

		if((self.pev.spawnflags & 1) == 1)
			self.pev.origin = m_CopyFromEntity.pev.origin;
	
		if((self.pev.spawnflags & 2) == 2)		
			self.pev.angles = m_CopyFromEntity.pev.angles;

		self.pev.nextthink = g_Engine.time;
	}
}

class CFuncRotatingFg : ScriptBaseEntity
{
	float m_flFanFriction = 1.0;
	float m_flInitialSpeed = 1.0;
	float m_flPushForce = 0.0;
	float m_flUpForce = 0.0;
	float m_flOutForce = 0.0;
	float m_flBlockUpForce = 0.0;
	float m_flBlockOutForce = 0.0;
	float m_flSlideForce = 0.0;
	float m_flMaxVelocity = 0.0;
	float m_flDynamicForce = 0.0;
	float m_flBlockCrushTime = 4.0;

	array<string> m_szHitSoundName = {
		"fallguys/impact1.ogg",
		"fallguys/impact2.ogg",
		"fallguys/impact3.ogg"
	};

	string m_szBlockSoundName = "fallguys/mecha.ogg";
	string m_szSlideSoundName = "fallguys/slide.ogg";

	void Precache()
	{
		BaseClass.Precache();

		g_SoundSystem.PrecacheSound( m_szHitSoundName[0] );
		g_SoundSystem.PrecacheSound( m_szHitSoundName[1] );
		g_SoundSystem.PrecacheSound( m_szHitSoundName[2] );

		g_SoundSystem.PrecacheSound( m_szBlockSoundName );
		g_SoundSystem.PrecacheSound( m_szSlideSoundName );
	}

	void Spawn()
	{
		Precache();

		if(self.pev.speed > 0)
			m_flInitialSpeed = self.pev.speed;

		if (m_flFanFriction == 0.0)
			m_flFanFriction = 1.0;

		self.pev.solid = SOLID_BSP;
		self.pev.movetype = MOVETYPE_PUSH;

		if ((self.pev.spawnflags & SF_BRUSH_ROTATE_Z_AXIS) == SF_BRUSH_ROTATE_Z_AXIS)
			self.pev.movedir = Vector(0.0, 0.0, 1.0);
		else if ((self.pev.spawnflags & SF_BRUSH_ROTATE_X_AXIS) == SF_BRUSH_ROTATE_X_AXIS)
			self.pev.movedir = Vector(1.0, 0.0, 0.0);
		else
			self.pev.movedir = Vector(0.0, 1.0, 0.0);

		if ((self.pev.spawnflags & SF_BRUSH_ROTATE_BACKWARDS) == SF_BRUSH_ROTATE_BACKWARDS)
			self.pev.movedir =  self.pev.movedir * (-1.0);

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		if ((self.pev.spawnflags & SF_BRUSH_ROTATE_INSTANT) == SF_BRUSH_ROTATE_INSTANT)
		{
			NextThink(self.pev.ltime + 1.5, false);
			SetThink(ThinkFunction(this.SUB_CallUseToggle));
		}
		else
		{
			NextThink(self.pev.ltime + 10.0, false);
			SetThink(ThinkFunction(this.Rotate));
		}
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{
		if(szKey == "fanfriction"){
			m_flFanFriction = atof(szValue) / 100.0;
			return true;
		}

		if(szKey == "pushforce"){
			m_flPushForce = atof(szValue);
			return true;
		}

		if(szKey == "upforce"){
			m_flUpForce = atof(szValue);
			return true;
		}

		if(szKey == "outforce"){
			m_flOutForce = atof(szValue);
			return true;
		}

		if(szKey == "blockupforce"){
			m_flBlockUpForce = atof(szValue);
			return true;
		}

		if(szKey == "blockoutforce"){
			m_flBlockOutForce = atof(szValue);
			return true;
		}

		if(szKey == "slideforce"){
			m_flSlideForce = atof(szValue);
			return true;
		}

		if(szKey == "maxvelocity"){
			m_flMaxVelocity = atof(szValue);
			return true;
		}

		if(szKey == "dynamicforce"){
			m_flDynamicForce = atof(szValue);
			return true;
		}

		if(szKey == "hitsound0"){
			m_szHitSoundName[0] = szValue;
			return true;
		}

		if(szKey == "hitsound2"){
			m_szHitSoundName[1] = szValue;
			return true;
		}

		if(szKey == "hitsound2"){
			m_szHitSoundName[2] = szValue;
			return true;
		}

		if(szKey == "blocksound"){
			m_szBlockSoundName = szValue;
			return true;
		}

		if(szKey == "blockcrushtime"){
			m_flBlockCrushTime = atof(szValue);
			return true;
		}

		if(szKey == "slidesound"){
			m_szSlideSoundName = szValue;
			return true;
		}


		return BaseClass.KeyValue( szKey, szValue );
	}

	bool IsRotating()
	{
		return (self.pev.avelocity.x == 0.0 && self.pev.avelocity.y == 0.0 && self.pev.avelocity.z == 0.0) ? false : true;
	}

	float GetCurrentRotateSpeed()
	{
		float speed = 0.0;
		if(self.pev.movedir.x != 0.0) 
		{
			speed = self.pev.avelocity.x;
		}
		else if(self.pev.movedir.y != 0.0)
		{
			speed = self.pev.avelocity.y;
		}
		else
		{
			speed = self.pev.avelocity.z;
		}
		return abs(speed);
	}

	float GetCurrentRotateDirection()
	{
		float vecdir = 0.0;
		if(self.pev.movedir.x != 0.0) 
		{
			vecdir = self.pev.movedir.x;
		}
		else if(self.pev.movedir.y != 0.0)
		{
			vecdir = self.pev.movedir.y;
		}
		else
		{
			vecdir = self.pev.movedir.z;
		}
		return vecdir;
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if ((self.pev.spawnflags & SF_BRUSH_ACCDCC) == SF_BRUSH_ACCDCC)
		{
			if(useType == USE_TOGGLE)
			{
				if (!IsRotating())
				{
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.SpinUp));
				}
				else
				{
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.SpinDown));
				}
			}
			else if(useType == USE_ON)
			{
				if (!IsRotating())
				{
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.SpinUp));
				}
			}
			else if(useType == USE_OFF)
			{
				//g_Game.AlertMessage( at_console, "Turning Off %1\n", string(self.pev.targetname));

				if (IsRotating())
				{
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.SpinDown));
				}
			}
			else if(useType == USE_SET && flValue > 0.0)
			{
				//g_Game.AlertMessage( at_console, "Change Speed of %1 to %2\n", string(self.pev.targetname), flValue);

				if (!IsRotating())
				{
					self.pev.speed = flValue;
				}
				else
				{
					if(self.pev.speed < flValue)
					{
						self.pev.speed = flValue;
						NextThink(self.pev.ltime + 0.1, false);
						SetThink(ThinkFunction(this.SpinUp));
					}
					else if(self.pev.speed > flValue)
					{
						self.pev.speed = flValue;
						NextThink(self.pev.ltime + 0.1, false);
						SetThink(ThinkFunction(this.SpinDown));
					}
				}
			}
		}
		else
		{
			if(useType == USE_TOGGLE)
			{
				if (!IsRotating())
				{
					self.pev.avelocity = self.pev.movedir * self.pev.speed;
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.Rotate));
				}
				else
				{
					self.pev.avelocity = Vector(0.0, 0.0, 0.0);
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.Rotate));
				}
			}
			else if(useType == USE_ON)
			{
				if (!IsRotating())
				{
					self.pev.avelocity = self.pev.movedir * self.pev.speed;
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.Rotate));
				}
			}
			else if(useType == USE_OFF)
			{
				//g_Game.AlertMessage( at_console, "Turning Off %1\n", string(self.pev.targetname));

				if (IsRotating())
				{
					self.pev.avelocity = g_vecZero;
					NextThink(self.pev.ltime + 0.1, false);
					SetThink(ThinkFunction(this.Rotate));
				}
			}
			else if(useType == USE_SET && flValue > 0.0)
			{
				//g_Game.AlertMessage( at_console, "Change speed of %1 to %2\n", string(self.pev.targetname), flValue);

				if (!IsRotating())
				{
					self.pev.speed = flValue;
				}
				else
				{
					if(self.pev.speed != flValue)
					{
						self.pev.speed = flValue;
						self.pev.avelocity = self.pev.movedir * self.pev.speed;
						NextThink(self.pev.ltime + 0.1, false);
						SetThink(ThinkFunction(this.Rotate));
					}
				}
			}
		}
	}

	float CalcDynamicForce(float flValue)
	{
		if(m_flDynamicForce > 0)
		{
			float flCurrentSpeed = GetCurrentRotateSpeed();
			if(flCurrentSpeed > 0)
				return flValue * pow(flCurrentSpeed / m_flInitialSpeed, m_flDynamicForce);
			else
				return flValue;
		}
		return flValue;
	}

	void Touch( CBaseEntity@ pOther )
	{
		if(self.pev.sequence == 1919810)
		{
			if(m_flPushForce > 0)
			{
				float flForce = CalcDynamicForce(m_flPushForce);

				Vector vDir = self.pev.vuser1;
				vDir = vDir.Normalize();

				pOther.pev.velocity = vDir * flForce;

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szHitSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}

			if(m_flUpForce > 0)
			{
				float flForce = CalcDynamicForce(m_flUpForce);

				if(pOther.pev.velocity.z < flForce)
					pOther.pev.velocity.z = flForce;
			}

			if(m_flOutForce > 0)
			{
				float flForce = CalcDynamicForce(m_flOutForce);

				Math.MakeVectors( self.pev.angles );

				Vector vOut = g_Engine.v_forward;

				if(m_flMaxVelocity > 0)
				{
					float flMaxVelocity = m_flMaxVelocity;
					if(m_flDynamicForce > 0)
					{
						flMaxVelocity = flMaxVelocity * (GetCurrentRotateSpeed() / m_flInitialSpeed) * m_flDynamicForce;
					}

					if(DotProduct(pOther.pev.velocity, vOut) > flMaxVelocity)
						return;
				}

				pOther.pev.velocity = vOut * flForce;
			}
			return;
		}

		if((self.pev.spawnflags & (SF_BRUSH_ROTATE_Z_AXIS | SF_BRUSH_ROTATE_X_AXIS)) == 0)
		{
			if(m_flSlideForce > 0)
			{
				float flForce = CalcDynamicForce(m_flSlideForce);

				if((pOther.pev.flags & FL_ONGROUND) == FL_ONGROUND && (pOther.pev.groundentity is self.edict() ))
				{
					Math.MakeVectors( self.pev.angles );

					Vector vRight = g_Engine.v_right;
					Vector vLeft = -g_Engine.v_right;
					Vector vDiff = (pOther.pev.origin - self.pev.origin);
					vDiff.z = 0;
					vDiff = vDiff.Normalize();

					if(DotProduct(vDiff, vLeft) > 0)
					{
						if(m_flMaxVelocity > 0)
						{
							float flMaxVelocity = CalcDynamicForce(m_flMaxVelocity);

							if(DotProduct(pOther.pev.velocity, vLeft) > flMaxVelocity)
								return;
						}

						pOther.pev.basevelocity = vLeft * flForce;

						if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

							g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSlideSoundName, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

							g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
						}
					}
					else if(DotProduct(vDiff, vRight) > 0)
					{
						if(m_flMaxVelocity > 0)
						{
							float flMaxVelocity = CalcDynamicForce(m_flMaxVelocity);

							if(DotProduct(pOther.pev.velocity, vRight) > flMaxVelocity)
								return;
						}

						pOther.pev.basevelocity = vRight * flForce;

						if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){
							
							g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSlideSoundName, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

							g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
						}
					}
				}
			}
		}
	}

	void Blocked( CBaseEntity@ pOther )
	{
		if(g_ArrayBlockPlayer[pOther.entindex()].IsBlocking)
		{
			if(g_Engine.time > g_ArrayBlockPlayer[pOther.entindex()].flStartBlockTime + m_flBlockCrushTime)
			{
				pOther.TakeDamage(self.pev, self.pev, 999999, DMG_CRUSH);
			}
			g_ArrayBlockPlayer[pOther.entindex()].flLastBlockTime = g_Engine.time;
		}
		else
		{
			g_ArrayBlockPlayer[pOther.entindex()].flStartBlockTime = g_Engine.time;
			g_ArrayBlockPlayer[pOther.entindex()].flLastBlockTime = g_Engine.time;
			g_ArrayBlockPlayer[pOther.entindex()].IsBlocking = true;

			if(g_Engine.time > g_ArrayBlockPlayer[pOther.entindex()].flLastSoundTime + 1.0){
				g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szBlockSoundName, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );
				g_ArrayBlockPlayer[pOther.entindex()].szPlayingSound = m_szBlockSoundName;
				g_ArrayBlockPlayer[pOther.entindex()].flLastSoundTime = g_Engine.time;
			}
		}

		if(m_flBlockOutForce > 0)
		{
			float flForce = CalcDynamicForce(m_flBlockOutForce);

			Vector vDir = pOther.pev.origin - self.pev.origin;
			vDir = vDir.Normalize();
			pOther.pev.velocity = vDir * flForce;

			if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()])
			{
				g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szHitSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

				g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
			}
		}

		if(m_flBlockUpForce > 0)
		{
			float flForce = CalcDynamicForce(m_flBlockUpForce);

			if(pOther.pev.velocity.z < flForce)
				pOther.pev.velocity.z = flForce;
		}
	}

	void NextThink(float thinkTime, const bool alwaysThink)
	{
		if (alwaysThink)
			self.pev.flags |= FL_ALWAYSTHINK;
		else
			self.pev.flags &= ~FL_ALWAYSTHINK;

		self.pev.nextthink = thinkTime;
	}

	void SUB_CallUseToggle()
	{
		self.Use(self, self, USE_ON, 0.0);
	}

	void Rotate()
	{
		NextThink(self.pev.ltime + 10.0, false);
		SetThink(ThinkFunction(this.Rotate));
	}

	void SpinUp()
	{
		NextThink(self.pev.ltime + 0.1, false);
		SetThink(ThinkFunction(this.SpinUp));

		self.pev.avelocity = self.pev.avelocity + (self.pev.movedir * (self.pev.speed * m_flFanFriction));

		Vector vecAVel = self.pev.avelocity;

		if (abs(vecAVel.x) >= abs(self.pev.movedir.x * self.pev.speed) &&
		 abs(vecAVel.y) >= abs(self.pev.movedir.y * self.pev.speed) &&
		 abs(vecAVel.z) >= abs(self.pev.movedir.z * self.pev.speed))
		{
			self.pev.avelocity = self.pev.movedir * self.pev.speed;

			SetThink(ThinkFunction(this.Rotate));
		}
	}

	void SpinDown()
	{
		NextThink(self.pev.ltime + 0.1, false);
		SetThink(ThinkFunction(this.SpinDown));

		self.pev.avelocity = self.pev.avelocity - (self.pev.movedir * (self.pev.speed * m_flFanFriction));

		Vector vecAVel = self.pev.avelocity;
		float vecdir = GetCurrentRotateDirection();

		if (((vecdir > 0.0) && (vecAVel.x <= 0.0 && vecAVel.y <= 0.0 && vecAVel.z <= 0.0)) || ((vecdir < 0.0) && (vecAVel.x >= 0.0 && vecAVel.y >= 0.0 && vecAVel.z >= 0.0)))
		{
			self.pev.avelocity = g_vecZero;
			SetThink(ThinkFunction(this.Rotate));
		}
	}
}

class CFuncTrainFg : ScriptBaseEntity
{
	float m_flWait = 0.0;
	Vector m_vecFinalDest;
	Vector m_vecSaveOrigin;
	CBaseEntity @m_pSaveTarget = null;
	CBaseEntity @m_pCurrentTarget = null;
	bool m_activated = false;
	
	float m_flPushForce = 0.0;
	float m_flUpForce = 0.0;
	float m_flBlockCrushTime = 4.0;

	array<string> m_szHitSoundName = {
		"fallguys/impact1.ogg",
		"fallguys/impact2.ogg",
		"fallguys/impact3.ogg"
	};
	
	string m_szBlockSoundName = "fallguys/mecha.ogg";

	void Precache()
	{
		BaseClass.Precache();

		g_SoundSystem.PrecacheSound( m_szHitSoundName[0] );
		g_SoundSystem.PrecacheSound( m_szHitSoundName[1] );
		g_SoundSystem.PrecacheSound( m_szHitSoundName[2] );

		g_SoundSystem.PrecacheSound( m_szBlockSoundName );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{		
		if(szKey == "wait"){
			m_flWait = atof(szValue);
			return true;
		}

		if(szKey == "pushforce"){
			m_flPushForce = atof(szValue);
			return true;
		}

		if(szKey == "upforce"){
			m_flUpForce = atof(szValue);
			return true;
		}

		if(szKey == "blockcrushtime"){
			m_flBlockCrushTime = atof(szValue);
			return true;
		}

		if(szKey == "hitsound0"){
			m_szHitSoundName[0] = szValue;
			return true;
		}

		if(szKey == "hitsound2"){
			m_szHitSoundName[1] = szValue;
			return true;
		}

		if(szKey == "hitsound2"){
			m_szHitSoundName[2] = szValue;
			return true;
		}

		if(szKey == "blocksound"){
			m_szBlockSoundName = szValue;
			return true;
		}

		if(szKey == "blockcrushtime"){
			m_flBlockCrushTime = atof(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Spawn()
	{
		Precache();

		if (self.pev.speed == 0)
			self.pev.speed = 100;

		if (string(self.pev.target).IsEmpty())
			g_Game.AlertMessage( at_console, "FuncTrain %1 with no target", string(self.pev.targetname));

		if(m_pSaveTarget is null){
			@m_pSaveTarget = @m_pCurrentTarget;
		} else {
			@m_pCurrentTarget = @m_pSaveTarget;
		}

		if(m_vecSaveOrigin == g_vecZero){
			m_vecSaveOrigin = self.pev.origin;
		} else {
			self.pev.origin = m_vecSaveOrigin;
		}

		self.pev.movetype = MOVETYPE_PUSH;

		if ((self.pev.spawnflags & SF_TRAIN_PASSABLE) == SF_TRAIN_PASSABLE)
			self.pev.solid = SOLID_NOT;
		else
			self.pev.solid = SOLID_BSP;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		m_activated = false;
	}

	void Touch( CBaseEntity@ pOther )
	{
		if(self.pev.sequence == 1919810)
		{
			if(m_flPushForce > 0.0)
			{
				Vector vDir = self.pev.vuser1;
				vDir = vDir.Normalize();
				pOther.pev.velocity = vDir * m_flPushForce;		

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szHitSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}

			if(m_flUpForce > 0)
			{
				if(pOther.pev.velocity.z < m_flUpForce)
					pOther.pev.velocity.z = m_flUpForce;
			}
		}
	}

	void Blocked( CBaseEntity@ pOther )
	{
		//g_Game.AlertMessage(at_aiconsole, "Train %1 Blocked by %2\n", string(self.pev.targetname), string(self.pev.netname));

		if(m_flPushForce > 0.0)
		{
			Vector vDir = pOther.pev.origin - self.pev.origin;
			vDir = vDir.Normalize();
			pOther.pev.velocity = vDir * m_flPushForce;

			if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

				g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szHitSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

				g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
			}
		}

		if(m_flUpForce > 0)
		{
			if(pOther.pev.velocity.z < m_flUpForce)
				pOther.pev.velocity.z = m_flUpForce;
		}
		
		if(g_ArrayBlockPlayer[pOther.entindex()].IsBlocking)
		{
			if(g_Engine.time > g_ArrayBlockPlayer[pOther.entindex()].flStartBlockTime + m_flBlockCrushTime)
			{
				pOther.TakeDamage(self.pev, self.pev, 999999, DMG_CRUSH);
			}
			g_ArrayBlockPlayer[pOther.entindex()].flLastBlockTime = g_Engine.time;
		}
		else
		{
			g_ArrayBlockPlayer[pOther.entindex()].flStartBlockTime = g_Engine.time;
			g_ArrayBlockPlayer[pOther.entindex()].flLastBlockTime = g_Engine.time;
			g_ArrayBlockPlayer[pOther.entindex()].IsBlocking = true;

			if(g_Engine.time > g_ArrayBlockPlayer[pOther.entindex()].flLastSoundTime + 1.0){
				g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szBlockSoundName, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );
				g_ArrayBlockPlayer[pOther.entindex()].szPlayingSound = m_szBlockSoundName;
				g_ArrayBlockPlayer[pOther.entindex()].flLastSoundTime = g_Engine.time;
			}
		}
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if (useType == USE_TOGGLE)
		{
			if ((self.pev.spawnflags & SF_TRAIN_WAIT_RETRIGGER) == SF_TRAIN_WAIT_RETRIGGER)
			{
				self.pev.spawnflags &= ~SF_TRAIN_WAIT_RETRIGGER;
				Next();
			}
			else
			{
				self.pev.spawnflags |= SF_TRAIN_WAIT_RETRIGGER;

				if (m_pCurrentTarget !is null)
				{
					self.pev.target = m_pCurrentTarget.pev.targetname;
				}

				self.pev.nextthink = 0;
				self.pev.velocity = g_vecZero;
			}
		}
		else if (useType == USE_ON)
		{
			Next();
		}
		else if (useType == USE_OFF)
		{
			self.pev.nextthink = 0;
			self.pev.velocity = g_vecZero;
		}
	}

	void NextThink(float thinkTime, const bool alwaysThink)
	{
		if (alwaysThink)
			self.pev.flags |= FL_ALWAYSTHINK;
		else
			self.pev.flags &= ~FL_ALWAYSTHINK;

		self.pev.nextthink = thinkTime;
	}

	void Activate()
	{
		if (!m_activated)
		{
			m_activated = true;
			CBaseEntity @pTarget = g_EntityFuncs.FindEntityByTargetname( null, self.pev.target );
			
			self.pev.target = pTarget.pev.target;
			@m_pCurrentTarget = @pTarget;
			g_EntityFuncs.SetOrigin(self, pTarget.pev.origin - (self.pev.mins + self.pev.maxs) * 0.5);

			if (string(self.pev.targetname).IsEmpty())
			{
				NextThink( self.pev.ltime + 0.1, false );
				SetThink( ThinkFunction( this.Next ) );
			}
			else
			{
				self.pev.spawnflags |= SF_TRAIN_WAIT_RETRIGGER;
			}
		}
	}

	void Wait()
	{
		if (m_pCurrentTarget.pev.message != 0 && !string(m_pCurrentTarget.pev.message).IsEmpty())
		{
			g_EntityFuncs.FireTargets( string(m_pCurrentTarget.pev.message), self, self, USE_TOGGLE, 0 );

			if ((m_pCurrentTarget.pev.spawnflags & SF_CORNER_FIREONCE) == SF_CORNER_FIREONCE)
				m_pCurrentTarget.pev.message = 0;
		}

		if ((m_pCurrentTarget.pev.spawnflags & SF_TRAIN_WAIT_RETRIGGER) == SF_TRAIN_WAIT_RETRIGGER || 
				(self.pev.spawnflags & SF_TRAIN_WAIT_RETRIGGER) == SF_TRAIN_WAIT_RETRIGGER)
		{
			self.pev.spawnflags |= SF_TRAIN_WAIT_RETRIGGER;

			self.pev.nextthink = 0;
			return;
		}

		if (m_flWait != 0)
		{
			NextThink( self.pev.ltime + m_flWait, false );
			SetThink( ThinkFunction( this.Next ) );
		}
		else
		{
			Next();
		}
	}

	void Next()
	{
		CBaseEntity @pTarget = self.GetNextTarget();

		if (pTarget is null)
		{
			return;
		}

		self.pev.message = self.pev.target;
		self.pev.target = pTarget.pev.target;
		m_flWait = pTarget.GetDelay();

		if (m_pCurrentTarget !is null && m_pCurrentTarget.pev.speed != 0)
		{
			self.pev.speed = m_pCurrentTarget.pev.speed;
			g_Game.AlertMessage(at_aiconsole, "Train %1 speed to %2\n", string(self.pev.targetname), self.pev.speed);
		}

		@m_pCurrentTarget = @pTarget;

		if ((m_pCurrentTarget.pev.spawnflags & SF_CORNER_TELEPORT) == SF_CORNER_TELEPORT)
		{
			self.pev.effects |= EF_NOINTERP;
			g_EntityFuncs.SetOrigin(self, pTarget.pev.origin - (self.pev.mins + self.pev.maxs) * 0.5);
			Wait();
		}
		else
		{
			self.pev.effects &= ~EF_NOINTERP;
			LinearMove(pTarget.pev.origin - (self.pev.mins + self.pev.maxs) * 0.5, self.pev.speed);
		}
	}

	void LinearMove(Vector vecDest, float flSpeed)
	{
		m_vecFinalDest = vecDest;

		if (vecDest == self.pev.origin)
		{
			LinearMoveDone();
			return;
		}

		Vector vecDestDelta = vecDest - self.pev.origin;
		float flTravelTime = vecDestDelta.Length() / flSpeed;
		NextThink( self.pev.ltime + flTravelTime, false );
		SetThink( ThinkFunction( this.LinearMoveDone ) );
		self.pev.velocity = vecDestDelta / flTravelTime;
	}

	void LinearMoveDone()
	{
		g_EntityFuncs.SetOrigin(self, m_vecFinalDest);
		self.pev.velocity = g_vecZero;
		self.pev.nextthink = -1;

		Wait();
	}
}

class CFuncTrackTrainFg : ScriptBaseEntity
{
	CPathTrack@ m_ppath = null;
	float m_length = 0.0;
	float m_height = 0.0;
	float m_speed = 0.0;
	float m_dir = 0.0;
	float m_startSpeed = 0.0;
	float m_flBank = 0.0;
	float m_oldSpeed = 0.0;
	
	float m_flPushForce = 0.0;
	float m_flUpForce = 0.0;
	float m_flBlockCrushTime = 4.0;

	array<string> m_szHitSoundName = {
		"fallguys/impact1.ogg",
		"fallguys/impact2.ogg",
		"fallguys/impact3.ogg"
	};
	
	string m_szBlockSoundName = "fallguys/mecha.ogg";

	void Precache()
	{
		BaseClass.Precache();

		g_SoundSystem.PrecacheSound( m_szHitSoundName[0] );
		g_SoundSystem.PrecacheSound( m_szHitSoundName[1] );
		g_SoundSystem.PrecacheSound( m_szHitSoundName[2] );

		g_SoundSystem.PrecacheSound( m_szBlockSoundName );
	}

	void Spawn()
	{
		if (self.pev.speed == 0)
			m_speed = 165;
		else
			m_speed = self.pev.speed;

		self.pev.speed = 0;
		self.pev.velocity = g_vecZero;
		self.pev.avelocity = g_vecZero;
		self.pev.impulse = int(m_speed);
		m_dir = 1;

		//g_Game.AlertMessage(at_console, "FuncTrain %1 Speed is %2\n", string(self.pev.targetname), m_speed);

		if ( string(self.pev.target).IsEmpty() )
			g_Game.AlertMessage( at_console, "FuncTrain %1 with no target", string(self.pev.targetname) );

		if ( ( self.pev.spawnflags & SF_TRACKTRAIN_PASSABLE ) != 0 )
			self.pev.solid = SOLID_NOT;
		else
			self.pev.solid = SOLID_BSP;
	
		self.pev.movetype = MOVETYPE_PUSH;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		self.pev.oldorigin = self.pev.origin;

		NextThink( self.pev.ltime + 0.1, false );
		SetThink( ThinkFunction( this.Find ) );
		Precache();
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{
		if(szKey == "wheels"){
			m_length = atof(szValue);
			return true;
		}
		
		if(szKey == "height"){
			m_height = atof(szValue);
			return true;
		}

		if(szKey == "startspeed"){
			m_startSpeed = atof(szValue);
			return true;
		}
			
		if(szKey == "bank"){
			m_flBank = atof(szValue);
			return true;
		}

		if(szKey == "pushforce"){
			m_flPushForce = atof(szValue);
			return true;
		}

		if(szKey == "upforce"){
			m_flUpForce = atof(szValue);
			return true;
		}

		if(szKey == "blockcrushtime"){
			m_flBlockCrushTime = atof(szValue);
			return true;
		}

		if(szKey == "hitsound0"){
			m_szHitSoundName[0] = szValue;
			return true;
		}

		if(szKey == "hitsound2"){
			m_szHitSoundName[1] = szValue;
			return true;
		}

		if(szKey == "hitsound2"){
			m_szHitSoundName[2] = szValue;
			return true;
		}

		if(szKey == "blocksound"){
			m_szBlockSoundName = szValue;
			return true;
		}

		if(szKey == "blockcrushtime"){
			m_flBlockCrushTime = atof(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if (useType != USE_SET)
		{
			if (!self.ShouldToggle(useType, (self.pev.speed != 0)))
				return;

			if (self.pev.speed == 0)
			{
				self.pev.speed = m_speed * m_dir;
				Next();
			}
			else
			{
				self.pev.speed = 0;
				self.pev.velocity = g_vecZero;
				self.pev.avelocity = g_vecZero;
				SetThink(null);
			}
		}
		else
		{
			float delta = flValue;
			delta = (int(self.pev.speed * 4) / int(m_speed)) * 0.25 + 0.25 * delta;

			if (delta > 1)
				delta = 1;
			else if (delta < -1)
				delta = -1;

			if ((self.pev.spawnflags & SF_TRACKTRAIN_FORWARDONLY) == SF_TRACKTRAIN_FORWARDONLY)
			{
				if (delta < 0)
					delta = 0;
			}

			self.pev.speed = m_speed * delta;
			Next();
			g_Game.AlertMessage(at_aiconsole, "TRAIN(%1), speed to %2\n", string(self.pev.targetname), self.pev.speed);
		}
	}

	void Touch( CBaseEntity@ pOther )
	{
		if(self.pev.sequence == 1919810)
		{
			if(m_flPushForce > 0.0)
			{
				Vector vDir = self.pev.vuser1;
				vDir = vDir.Normalize();
				pOther.pev.velocity = vDir * m_flPushForce;		

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szHitSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}

			if(m_flUpForce > 0)
			{
				if(pOther.pev.velocity.z < m_flUpForce)
					pOther.pev.velocity.z = m_flUpForce;
			}
		}
	}

	void Blocked( CBaseEntity@ pOther )
	{
		//g_Game.AlertMessage(at_aiconsole, "FuncTrain %1 Blocked by %2\n", string(self.pev.targetname), string(self.pev.netname));

		if(m_flPushForce > 0.0)
		{
			Vector vDir = pOther.pev.origin - self.pev.origin;
			vDir = vDir.Normalize();
			pOther.pev.velocity = vDir * m_flPushForce;

			if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

				g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szHitSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

				g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
			}
		}

		if(m_flUpForce > 0)
		{
			if(pOther.pev.velocity.z < m_flUpForce)
				pOther.pev.velocity.z = m_flUpForce;
		}
		
		if(g_ArrayBlockPlayer[pOther.entindex()].IsBlocking)
		{
			if(g_Engine.time > g_ArrayBlockPlayer[pOther.entindex()].flStartBlockTime + m_flBlockCrushTime)
			{
				pOther.TakeDamage(self.pev, self.pev, 999999, DMG_CRUSH);
			}
			g_ArrayBlockPlayer[pOther.entindex()].flLastBlockTime = g_Engine.time;
		}
		else
		{
			g_ArrayBlockPlayer[pOther.entindex()].flStartBlockTime = g_Engine.time;
			g_ArrayBlockPlayer[pOther.entindex()].flLastBlockTime = g_Engine.time;
			g_ArrayBlockPlayer[pOther.entindex()].IsBlocking = true;

			if(g_Engine.time > g_ArrayBlockPlayer[pOther.entindex()].flLastSoundTime + 1.0){
				g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_BODY, m_szBlockSoundName, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );
				g_ArrayBlockPlayer[pOther.entindex()].szPlayingSound = m_szBlockSoundName;
				g_ArrayBlockPlayer[pOther.entindex()].flLastSoundTime = g_Engine.time;
			}
		}
	}

	void NextThink(float thinkTime, const bool alwaysThink)
	{
		if (alwaysThink)
			self.pev.flags |= FL_ALWAYSTHINK;
		else
			self.pev.flags &= ~FL_ALWAYSTHINK;

		self.pev.nextthink = thinkTime;
	}

	void SUB_CallUseToggle()
	{
		self.Use(self, self, USE_ON, 0.0);
	}

	float Fix(float angle)
	{
		while (angle < 0)
			angle += 360;
		while (angle > 360)
			angle -= 360;

		return angle;
	}

	Vector FixupAngles(Vector v)
	{
		v.x = Fix(v.x);
		v.y = Fix(v.y);
		v.z = Fix(v.z);

		return v;
	}

	void Next()
	{
		float time = 0.5;

		if (self.pev.speed == 0.0)
		{
			g_Game.AlertMessage( at_aiconsole, "TRAIN(%1): Speed is 0\n", string(self.pev.targetname));
			return;
		}

		if (m_ppath is null)
		{
			g_Game.AlertMessage( at_aiconsole, "TRAIN(%1): Lost path\n", string(self.pev.targetname));
			return;
		}

		Vector nextPos = self.pev.origin;
		nextPos.z -= m_height;
		CPathTrack@ pnext = m_ppath.LookAhead(nextPos, nextPos, self.pev.speed * 0.1, true);
		nextPos.z += m_height;

		self.pev.velocity = (nextPos - self.pev.origin) * 10;
		Vector nextFront = self.pev.origin;
		nextFront.z -= m_height;

		if (m_length > 0)
			m_ppath.LookAhead(nextFront, nextFront, m_length, false);
		else
			m_ppath.LookAhead(nextFront, nextFront, 100, false);

		nextFront.z += m_height;

		Vector delta = nextFront - self.pev.origin;
		Vector angles = Math.VecToAngles(delta);
		angles.y += 180;

		angles = FixupAngles( angles );
		self.pev.angles = FixupAngles( self.pev.angles );

		if ( pnext is null || (delta.x == 0 && delta.y == 0) )
			angles = self.pev.angles;

		float vy, vx;

		if ((self.pev.spawnflags & SF_TRACKTRAIN_NOPITCH) == 0)
			vx = Math.AngleDistance(angles.x, self.pev.angles.x);
		else
			vx = 0;

		vy = Math.AngleDistance(angles.y, self.pev.angles.y);
		self.pev.avelocity.y = vy * 10;
		self.pev.avelocity.x = vx * 10;

		if ( m_flBank != 0 )
		{
			if ( self.pev.avelocity.y < -5 )
				self.pev.avelocity.z = Math.AngleDistance( Math.ApproachAngle( -m_flBank, self.pev.angles.z, m_flBank*2 ), self.pev.angles.z);
			else if ( self.pev.avelocity.y > 5 )
				self.pev.avelocity.z = Math.AngleDistance( Math.ApproachAngle( m_flBank, self.pev.angles.z, m_flBank*2 ), self.pev.angles.z);
			else
				self.pev.avelocity.z = Math.AngleDistance( Math.ApproachAngle( 0, self.pev.angles.z, m_flBank*4 ), self.pev.angles.z) * 4;
		}

		if ( pnext !is null )
		{
			if (pnext != m_ppath)
			{
				CPathTrack@ pFire = (self.pev.speed >= 0) ? pnext : m_ppath;
				@m_ppath = pnext;

				if ( !string( pFire.pev.message ).IsEmpty() )
				{
					g_EntityFuncs.FireTargets( string(pFire.pev.message), self, self, USE_TOGGLE, 0 );

					if ((pFire.pev.spawnflags & SF_PATH_FIREONCE) == SF_PATH_FIREONCE)
						pFire.pev.message = 0;
				}

				if ((pFire.pev.spawnflags & SF_PATH_DISABLE_TRAIN) == SF_PATH_DISABLE_TRAIN)
					self.pev.spawnflags |= SF_TRACKTRAIN_NOCONTROL;

				if ((self.pev.spawnflags & SF_TRACKTRAIN_NOCONTROL) == SF_TRACKTRAIN_NOCONTROL)
				{
					if ( pFire.pev.speed != 0 )
					{
						self.pev.speed = pFire.pev.speed;
						g_Game.AlertMessage( at_aiconsole, "TrackTrain %1 speed to %2\n", string(self.pev.targetname), self.pev.speed);
					}
				}
			}

			SetThink( ThinkFunction( this.Next ) );
			NextThink( self.pev.ltime + time, true );
		}
		else
		{
			self.pev.velocity = (nextPos - self.pev.origin);
			self.pev.avelocity = g_vecZero;

			float distance = self.pev.velocity.Length();
			m_oldSpeed = self.pev.speed;
			self.pev.speed = 0;

			if (distance > 0)
			{
				time = distance / m_oldSpeed;
				self.pev.velocity = self.pev.velocity * (m_oldSpeed / distance);
				SetThink( ThinkFunction( this.DeadEnd ) );
				NextThink( self.pev.ltime + time, false );
			}
			else
				DeadEnd();
		}
	}

	void DeadEnd()
	{
		CPathTrack@ pTrack = m_ppath;

		g_Game.AlertMessage( at_aiconsole, "TRAIN \"%1\" dead end\n", string(self.pev.targetname) );

		if ( pTrack !is null )
		{
			CPathTrack@ pNext = null;

			if (m_oldSpeed < 0)
			{
				do
				{
					@pNext = pTrack.ValidPath( pTrack.GetPrevious(), true );

					if ( pNext !is null )
						@pTrack = pNext;
				}
				while ( pNext !is null );
			}
			else
			{
				do
				{
					@pNext = pTrack.ValidPath( pTrack.GetNext(), true );

					if ( pNext !is null )
						@pTrack = pNext;
				}
				while ( pNext !is null );
			}
		}

		self.pev.velocity = g_vecZero;
		self.pev.avelocity = g_vecZero;

		if ( pTrack !is null )
		{
			g_Game.AlertMessage(at_aiconsole, "TRAIN \"%1\" dead end at %1\n", string(pTrack.pev.targetname));

			if ( !string( pTrack.pev.netname ).IsEmpty() )
				g_EntityFuncs.FireTargets(string(pTrack.pev.netname), self, self, USE_TOGGLE, 0 );
		}
	}

	void Find()
	{
		@m_ppath = cast<CPathTrack@>( g_EntityFuncs.FindEntityByTargetname( null, self.pev.target ) );

		if ( m_ppath is null ){
			g_Game.AlertMessage( at_error,  "func_track_train %1 found no target\n", string(self.pev.targetname) );
			return;
		}

		entvars_t@ pevTarget = m_ppath.pev;

		if (!pevTarget.ClassNameIs( "path_track" ))
		{
			g_Game.AlertMessage( at_error,  "func_track_train %1 must be on a path of path_track\n", string(self.pev.targetname) );
			@m_ppath = null;
			return;
		}

		Vector nextPos = pevTarget.origin;
		nextPos.z += m_height;

		Vector look = nextPos;
		look.z -= m_height;
		m_ppath.LookAhead( look, look, m_length, false );
		look.z += m_height;

		self.pev.angles = Math.VecToAngles( look - nextPos );
		self.pev.angles.y += 180;

		if ( ( self.pev.spawnflags & SF_TRACKTRAIN_NOPITCH ) != 0 )
			self.pev.angles.x = 0;

		g_EntityFuncs.SetOrigin(self, nextPos);
		NextThink( self.pev.ltime + 0.1, false );
		SetThink( ThinkFunction( this.Next ) );
		self.pev.speed = m_startSpeed;
	}

	void NearestPath()
	{
		CBaseEntity@ pTrack = null;
		CBaseEntity@ pNearest = null;
		float closest = 1024;

		while ((@pTrack = @g_EntityFuncs.FindEntityInSphere( pTrack, self.pev.origin, 1024 )) !is null)
		{
			if ( ( pTrack.pev.flags & (FL_CLIENT|FL_MONSTER) ) == 0 && pTrack.pev.ClassNameIs( "path_track" ) )
			{
				float dist = (self.pev.origin - pTrack.pev.origin).Length();

				if (dist < closest)
				{
					closest = dist;
					@pNearest = @pTrack;
				}
			}
		}

		if (pNearest is null)
		{
			g_Game.AlertMessage(at_console, "Can't find a nearby track !!!\n");
			SetThink( null );
			return;
		}

		g_Game.AlertMessage(at_aiconsole, "TRAIN: %1, Nearest track is %2\n", string(self.pev.targetname), string(pNearest.pev.targetname));
		@pTrack = cast<CPathTrack@>(pNearest).GetNext();

		if (pTrack !is null)
		{
			if ( (self.pev.origin - pTrack.pev.origin).Length() < (self.pev.origin - pNearest.pev.origin).Length() )
				@pNearest = pTrack;
		}

		@m_ppath = cast<CPathTrack@>(pNearest);

		if ( self.pev.speed != 0 )
		{
			NextThink( self.pev.ltime + 0.1, false );
			SetThink( ThinkFunction( this.Next ) );
		}
	}

	void OverrideReset()
	{
		NextThink( self.pev.ltime + 0.1, false );
		SetThink( ThinkFunction( this.NearestPath ) );
	}
}

class CFuncLever : ScriptBaseEntity
{
	float m_flInertia = 1.0;
	float m_flLimitAngle = 80.0;
	float m_flLimitBounceVelocity = 10.0;
	float m_flLimitBounceFriction = 0.5;
	float m_flReturnAngle = 45.0;
	float m_flReturnForce = 0;

	void Spawn()
	{
		self.pev.solid = SOLID_BSP;
		self.pev.movetype = MOVETYPE_PUSH;

		if ((self.pev.spawnflags & 1) == 1)
			self.pev.movedir = Vector(0, 0, 1);
		else if ((self.pev.spawnflags & 2) == 2)
			self.pev.movedir = Vector(1, 0, 0);

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		NextThink(self.pev.ltime + 0.1, false);
		SetThink(ThinkFunction(this.Spin));
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{
		if(szKey == "inertia"){
			m_flInertia = atof(szValue);
			return true;
		}
		if(szKey == "limitangle"){
			m_flLimitAngle = atof(szValue);
			return true;
		}
		if(szKey == "limitbouncevelocity"){
			m_flLimitBounceVelocity = atof(szValue);
			return true;
		}
		if(szKey == "limitbouncefriction"){
			m_flLimitBounceFriction = atof(szValue);
			return true;
		}
		if(szKey == "returnangle"){
			m_flReturnAngle = atof(szValue);
			return true;
		}
		if(szKey == "returnforce"){
			m_flReturnForce = atof(szValue);
			return true;
		}
		return BaseClass.KeyValue( szKey, szValue );
	}

	void NextThink(float thinkTime, const bool alwaysThink)
	{
		if (alwaysThink)
			self.pev.flags |= FL_ALWAYSTHINK;
		else
			self.pev.flags &= ~FL_ALWAYSTHINK;

		self.pev.nextthink = thinkTime;
	}

	void Spin()
	{
		//g_Game.AlertMessage( at_console, "My avel %1 %2 %3\n", self.pev.avelocity.x, self.pev.avelocity.y, self.pev.avelocity.z );
		//g_Game.AlertMessage( at_console, "My angle %1 %2 %3\n", self.pev.angles.x, self.pev.angles.y, self.pev.angles.z );

		float flNumForce = 0;
		float flMomentOfForceTotal = 0;

		int iLimited = 0;

		if ((self.pev.spawnflags & 1) == 1)
		{
			if(self.pev.angles.z > m_flLimitAngle)
			{
				if(self.pev.avelocity.z > m_flLimitBounceVelocity)
					self.pev.avelocity.z *= -m_flLimitBounceFriction;
				else
					self.pev.avelocity.z = -m_flLimitBounceVelocity * m_flLimitBounceFriction;
				iLimited = 1;
			}
			else if(self.pev.angles.z < -m_flLimitAngle)
			{
				if(self.pev.avelocity.z < -m_flLimitBounceVelocity)
					self.pev.avelocity.z *= -m_flLimitBounceFriction;
				else
					self.pev.avelocity.z = m_flLimitBounceVelocity * m_flLimitBounceFriction;
				iLimited = 2;
			}
			else if(self.pev.angles.z > m_flReturnAngle)
			{
				flNumForce += 1.0;
				flMomentOfForceTotal -= m_flReturnForce;
				iLimited = -1;
			}
			else if(self.pev.angles.z < -m_flReturnAngle)
			{
				flNumForce += 1.0;
				flMomentOfForceTotal += m_flReturnForce;
				iLimited = -2;
			}
		}
		else if ((self.pev.spawnflags & 2) == 2)
		{
			if(self.pev.angles.x > m_flLimitAngle)
			{
				if(self.pev.avelocity.x > m_flLimitBounceVelocity)
					self.pev.avelocity.x *= -m_flLimitBounceFriction;
				else
					self.pev.avelocity.x = -m_flLimitBounceVelocity * m_flLimitBounceFriction;
				iLimited = 1;
			}
			else if(self.pev.angles.x < -m_flLimitAngle)
			{
				if(self.pev.avelocity.x < -m_flLimitBounceVelocity)
					self.pev.avelocity.x *= -m_flLimitBounceFriction;
				else
					self.pev.avelocity.x = m_flLimitBounceVelocity * m_flLimitBounceFriction;
				iLimited = 2;
			}
			else if(self.pev.angles.x > m_flReturnAngle)
			{
				flNumForce += 1.0;
				flMomentOfForceTotal -= m_flReturnForce;
				iLimited = -1;
			}
			else if(self.pev.angles.x < -m_flReturnAngle)
			{
				flNumForce += 1.0;
				flMomentOfForceTotal += m_flReturnForce;
				iLimited = -2;
			}
		}

		if(iLimited <= 0)
		{
			for (int i = 0; i <= g_Engine.maxClients; i++)
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
				if(pPlayer !is null && pPlayer.IsAlive())
				{
					if((pPlayer.pev.flags & FL_ONGROUND) == FL_ONGROUND && (pPlayer.pev.groundentity is self.edict() ))
					{
						float flAngle = 0;
						float flOffset = 0;
						Vector v1 = pPlayer.pev.origin;
						Vector v2 = self.pev.origin;
						if ((self.pev.spawnflags & 1) == 1)
						{
							v1.x = v2.x;
							v1.z -= pPlayer.pev.maxs.z;
							flOffset = (v1-v2).Length();
							flAngle = self.pev.angles.z;

							if(v1.y > v2.y)
								flOffset *= -1.0;
						}
						else if ((self.pev.spawnflags & 2) == 2)
						{
							v1.y = v2.y;
							v1.z -= pPlayer.pev.maxs.z;
							flOffset = (v1-v2).Length();
							flAngle = self.pev.angles.x;

							if(v1.x > v2.x)
								flOffset *= -1.0;
						}

						float flGravity = 800;

						float flAngleDiff = 90 - flAngle;
						float flMomentOfForce = flGravity * flOffset * sin(flAngleDiff * 2 * 3.14159 / 360.0);
						
						flMomentOfForceTotal += flMomentOfForce;
						flNumForce += 1.0;

						//g_Game.AlertMessage( at_console, "Found %1 on me, flOffset %2, flAngleDiff %3, flMomentOfForce %4 %5\n", pPlayer.pev.netname, flOffset, flAngleDiff, flMomentOfForce, pPlayer.pev.maxs.z );
					}
				}
			}
		}

		float flAngleAcc = 0;
		if(flNumForce > 0)
		{
			flAngleAcc = (flMomentOfForceTotal / flNumForce) / m_flInertia;
			self.pev.avelocity = self.pev.avelocity + self.pev.movedir * (flAngleAcc * g_Engine.frametime);

			NextThink(self.pev.ltime + 0.1, true);
			SetThink(ThinkFunction(this.Spin));
		}
		else
		{
			NextThink(self.pev.ltime + 0.1, false);
			SetThink(ThinkFunction(this.Spin));
		}
	}
}

class CFuncBarrier : ScriptBaseEntity
{
	Vector m_vecLeft;
	Vector m_vecRight;
	Vector m_vecForward;

	float m_flPushForce = 0.0;
	float m_flTouchForce = 0.0;
	float m_flMaxVelocity = 0.0;

	array<string> m_szSoundName(3);

	void Precache()
	{
		BaseClass.Precache();
		
		m_szSoundName[0] = "fallguys/bounce.ogg";
		m_szSoundName[1] = "fallguys/bounce2.ogg";
		m_szSoundName[2] = "fallguys/bounce3.ogg";

		g_SoundSystem.PrecacheSound( m_szSoundName[0] );
		g_SoundSystem.PrecacheSound( m_szSoundName[1] );
		g_SoundSystem.PrecacheSound( m_szSoundName[2] );
	}

	void Spawn()
	{
		Precache();

		self.pev.solid = SOLID_BSP;
		self.pev.movetype = MOVETYPE_PUSH;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		Vector angles = self.pev.angles;

		Math.MakeVectors( angles );

		m_vecLeft = g_Engine.v_right * -1.0;
		m_vecRight = g_Engine.v_right;
		m_vecForward = g_Engine.v_forward;

		self.pev.angles = Vector(0.0, 0.0, 0.0);
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{
		if(szKey == "pushforce"){
			m_flPushForce = atof(szValue);
			return true;
		}

		if(szKey == "touchforce"){
			m_flTouchForce = atof(szValue);
			return true;
		}

		if(szKey == "maxvelocity"){
			m_flMaxVelocity = atof(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Touch( CBaseEntity@ pOther )
	{
		if ( pOther is null || !pOther.IsPlayer() || !pOther.IsAlive())
			return;

		if((pOther.pev.flags & FL_ONGROUND) == FL_ONGROUND && (pOther.pev.groundentity is self.edict() ))
		{
			Vector vDiff = (pOther.pev.origin - self.pev.origin);
			vDiff.z = 0;
			vDiff = vDiff.Normalize();

			if(DotProduct(vDiff, m_vecLeft) > 0)
			{
				if(m_flMaxVelocity > 0.0 && DotProduct(pOther.pev.velocity, m_vecLeft) > m_flMaxVelocity)
					return;

				pOther.pev.basevelocity = m_vecLeft * m_flPushForce;

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}
			else if(DotProduct(vDiff, m_vecRight) > 0)
			{
				if(m_flMaxVelocity > 0.0 && DotProduct(pOther.pev.velocity, m_vecRight) > m_flMaxVelocity)
					return;

				pOther.pev.basevelocity = m_vecRight * m_flPushForce;

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){
					
					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}
		}
		else
		{
			Vector vDiff = (pOther.pev.origin - self.pev.origin);
			vDiff.z = 0;
			vDiff = vDiff.Normalize();

			if(DotProduct(vDiff, m_vecLeft) > 0)
			{
				if(m_flMaxVelocity > 0.0 && DotProduct(pOther.pev.velocity, m_vecLeft) > m_flMaxVelocity)
					return;

				pOther.pev.basevelocity = m_vecLeft * m_flTouchForce;

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}
			else if(DotProduct(vDiff, m_vecRight) > 0)
			{
				if(m_flMaxVelocity > 0.0 && DotProduct(pOther.pev.velocity, m_vecRight) > m_flMaxVelocity)
					return;

				pOther.pev.basevelocity = m_vecRight * m_flTouchForce;

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){
					
					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}
		}
	}
}

class CFuncBouncer : ScriptBaseEntity
{
	float m_flPushForce = 0.0;
	float m_flUpForce = 0.0;
	float m_flMaxVelocity = 0.0;

	array<string> m_szSoundName(3);

	void Precache()
	{
		BaseClass.Precache();
		
		m_szSoundName[0] = "fallguys/bounce.ogg";
		m_szSoundName[1] = "fallguys/bounce2.ogg";
		m_szSoundName[2] = "fallguys/bounce3.ogg";

		g_SoundSystem.PrecacheSound( m_szSoundName[0] );
		g_SoundSystem.PrecacheSound( m_szSoundName[1] );
		g_SoundSystem.PrecacheSound( m_szSoundName[2] );
	}

	void Spawn()
	{
		Precache();

		self.pev.solid = SOLID_BSP;
		self.pev.movetype = MOVETYPE_PUSH;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{
		if(szKey == "pushforce"){
			m_flPushForce = atof(szValue);
			return true;
		}

		if(szKey == "upforce"){
			m_flUpForce = atof(szValue);
			return true;
		}

		if(szKey == "maxvelocity"){
			m_flMaxVelocity = atof(szValue);			
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Touch( CBaseEntity@ pOther )
	{
		if ( pOther is null || !pOther.IsPlayer() || !pOther.IsAlive())
			return;

		if((pOther.pev.flags & FL_ONGROUND) == FL_ONGROUND && (pOther.pev.groundentity is self.edict() ))
		{
			if(m_flUpForce > 0.0)
			{
				if(m_flMaxVelocity > 0.0 && pOther.pev.velocity.z > m_flMaxVelocity)
					return;

				pOther.pev.basevelocity.z = m_flUpForce;
				pOther.pev.flags &= ~FL_ONGROUND;

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}
		}
		else
		{
			if(m_flPushForce > 0.0)
			{
				Vector vDiff = pOther.pev.origin - self.pev.origin;
				vDiff.z = 0;
				vDiff = vDiff.Normalize();

				if(m_flMaxVelocity > 0.0 && DotProduct(pOther.pev.velocity, vDiff) > m_flMaxVelocity)
					return;

				pOther.pev.basevelocity = vDiff * m_flPushForce;

				if(g_Engine.time > g_ArrayBouncePlayer[pOther.entindex()]){

					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, m_szSoundName[Math.RandomLong(0, 2)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

					g_ArrayBouncePlayer[pOther.entindex()] = g_Engine.time + 0.5;
				}
			}
		}
	}
}

class CTriggerHUDSprite : ScriptBaseEntity
{
	string m_szSprName = "";
	string m_szSoundName = "";
	int m_nFrameNum = 0;
	float m_flOffsetX = 0;
	float m_flOffsetY = 0;
	int m_nSprWidth = 0;
	int m_nSprHeight = 0;
	int m_iChannel = 14;
	float m_flHoldTime = 1.0;
	RGBA m_Color = RGBA_WHITE;

	void Precache()
	{
		BaseClass.Precache();
		if(m_szSprName != ""){
			g_Game.PrecacheModel( "sprites/" +  m_szSprName );
    		g_Game.PrecacheGeneric("sprites/" + m_szSprName );
		}
		if(m_szSoundName != ""){
    		g_Game.PrecacheGeneric( "sound/" + m_szSoundName );
		}
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "sprite"){
		    m_szSprName = szValue;
			return true;
		}
		if(szKey == "framenum"){
			m_nFrameNum = atoi(szValue);
			return true;
		}
		if(szKey == "holdtime"){
			m_flHoldTime = atof(szValue);
			return true;
		}
		if(szKey == "sound"){
		    m_szSoundName = szValue;
			return true;
		}
		if(szKey == "offsetx"){
		    m_flOffsetX = atof(szValue);
			return true;
		}
		if(szKey == "offsety"){
		    m_flOffsetY = atof(szValue);
			return true;
		}
		if(szKey == "channel"){
		    m_iChannel = atoi(szValue);
			return true;
		}
		if(szKey == "sprwidth"){
		    m_nSprWidth = atoi(szValue);
			return true;
		}
		if(szKey == "sprheight"){
		    m_nSprHeight = atoi(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void SendSprite( CBasePlayer@ pPlayer, const string& in strName, uint framenum = 0, float hold = 0.8 )
	{
		g_PlayerFuncs.HudToggleElement(pPlayer, m_iChannel, true);

		HUDSpriteParams params;
		params.channel = m_iChannel;
		params.flags = HUD_SPR_MASKED; 
		if((self.pev.spawnflags & 1) == 1)
			params.flags |= HUD_ELEM_SCR_CENTER_X;
		if((self.pev.spawnflags & 2) == 2)
			params.flags |= HUD_ELEM_SCR_CENTER_Y;
		params.spritename = strName;
		params.x = m_flOffsetX;
		params.y = m_flOffsetY;
		params.framerate = 0;
		params.frame = framenum;
		params.holdTime = hold;
		params.color1 = m_Color;
		params.fadeoutTime = 0.1;
		params.width = m_nSprWidth;
		params.height = m_nSprHeight;
		g_PlayerFuncs.HudCustomSprite( pPlayer, params );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if(m_szSprName != "")
		{
			if(useType == USE_OFF)
			{
				if(pActivator !is null && pActivator.IsPlayer() && pActivator.IsNetClient())
				{
					CBasePlayer@ pPlayer = cast<CBasePlayer@>(@pActivator);
					if(pPlayer.IsConnected())
						g_PlayerFuncs.HudToggleElement(pPlayer, m_iChannel, false);
				}
				else
				{
					for (int i = 0; i <= g_Engine.maxClients; i++)
					{
						CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
						if(pPlayer !is null && pPlayer.IsConnected())
							g_PlayerFuncs.HudToggleElement(pPlayer, m_iChannel, false);
					}
				}
			}
			else
			{
				if(pActivator !is null && pActivator.IsPlayer() && pActivator.IsNetClient())
				{
					CBasePlayer@ pPlayer = cast<CBasePlayer@>(@pActivator);
					if(pPlayer.IsConnected())
						SendSprite(pPlayer, m_szSprName, m_nFrameNum, m_flHoldTime);
				}
				else
				{
					for (int i = 0; i <= g_Engine.maxClients; i++)
					{
						CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
						if(pPlayer !is null && pPlayer.IsConnected())
							SendSprite(pPlayer, m_szSprName, m_nFrameNum, m_flHoldTime);
					}
				}
			}
		}

		if(m_szSoundName != "")
		{
			if(useType == USE_OFF)
			{

			}
			else
			{
				if(pActivator !is null && pActivator.IsPlayer() && pActivator.IsNetClient())
				{
					CBasePlayer@ pPlayer = cast<CBasePlayer@>(@pActivator);
					NetworkMessage message( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
						message.WriteString("spk " + m_szSoundName+"\n");
					message.End();
				}
				else
				{
					for (int i = 0; i <= g_Engine.maxClients; i++)
					{
						CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
						if(pPlayer !is null && pPlayer.IsConnected())
						{
							NetworkMessage message( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
								message.WriteString("spk " + m_szSoundName+"\n");
							message.End();
						}
					}
				}
			}
		}
	}
}

class CTriggerHUDCountdown : ScriptBaseEntity
{
	int m_nCountNum = 0;
	int m_nCurrentCount = 0;
	int m_nCurrentAccum = 0;
	float m_flOffsetX = 0;
	float m_flOffsetY = 0;
	int m_iChannel = 15;
	RGBA m_Color = RGBA_WHITE;

	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "countnum"){
			m_nCountNum = atoi(szValue);
			return true;
		}
		if(szKey == "offsetx"){
		    m_flOffsetX = atof(szValue);
			return true;
		}
		if(szKey == "offsety"){
		    m_flOffsetY = atof(szValue);
			return true;
		}
		if(szKey == "channel"){
		    m_iChannel = atoi(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void SendCountdown( CBasePlayer@ pPlayer, float countnum = 0.0, float hold = 0.8 )
	{
		g_PlayerFuncs.HudToggleElement(pPlayer, m_iChannel, true);

		HUDNumDisplayParams params;
		params.channel = m_iChannel;
		params.flags = HUD_TIME_MINUTES | HUD_TIME_SECONDS | HUD_TIME_COUNT_DOWN; 
		if((self.pev.spawnflags & 1) == 1)
			params.flags |= HUD_ELEM_SCR_CENTER_X;
		if((self.pev.spawnflags & 2) == 2)
			params.flags |= HUD_ELEM_SCR_CENTER_Y;
		params.value = countnum;
		params.defdigits = 4;
		params.maxdigits = 4;
		params.x = m_flOffsetX;
		params.y = m_flOffsetY;
		params.holdTime = hold;
		params.color1 = m_Color;
		params.fadeoutTime = 0.2;

		g_PlayerFuncs.HudTimeDisplay(pPlayer, params);

		//g_Game.AlertMessage( at_console, "Send Countdown to %1\n", pPlayer.pev.netname );
	}

	void UpdateCountdown( CBasePlayer@ pPlayer, float countnum = 0.0 )
	{
		g_PlayerFuncs.HudUpdateTime(pPlayer, m_iChannel, countnum);
	}

	void Think()
	{
		if(m_nCurrentCount > 0)
		{
			for (int i = 0; i <= g_Engine.maxClients; i++)
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
				if(pPlayer !is null && pPlayer.IsConnected())
				{
					if((m_nCurrentAccum % 5) == 0)
						SendCountdown(pPlayer, m_nCurrentCount, m_nCurrentCount);
					else
						UpdateCountdown(pPlayer, m_nCurrentCount);
				}
			}

			m_nCurrentAccum += 1;
			m_nCurrentCount -= 1;

			self.pev.nextthink = g_Engine.time + 1.0;
		}
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if(useType == USE_TOGGLE)
		{
			if(m_nCurrentCount == 0)
			{
				m_nCurrentCount = m_nCountNum;
				m_nCurrentAccum = 0;
				Think();
			}
			else
			{
				m_nCurrentCount = m_nCountNum;
				m_nCurrentAccum = 0;
				self.pev.nextthink = 0;
			}
		}
		else if(useType == USE_ON)
		{
			m_nCurrentCount = m_nCountNum;
			m_nCurrentAccum = 0;
			Think();
		}
		else if(useType == USE_OFF)
		{
			if(m_nCurrentCount > 0)
			{
				for (int i = 0; i <= g_Engine.maxClients; i++)
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
					if(pPlayer !is null && pPlayer.IsConnected())
					{
						SendCountdown(pPlayer, 0, 0);
					}
				}
			}

			m_nCurrentCount = m_nCountNum;
			m_nCurrentAccum = 0;
			self.pev.nextthink = 0;
		}
	}
}

class CTriggerSpectator : ScriptBaseEntity
{
	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if(useType == USE_TOGGLE)
		{
			if ( pActivator is null || !pActivator.IsPlayer())
				return;

			CBasePlayer@ pPlayer = cast<CBasePlayer@>(@pActivator);

			pPlayer.pev.health = 0.0;
			pPlayer.pev.deadflag = DEAD_DYING;
			pPlayer.pev.takedamage = DAMAGE_NO;
			pPlayer.pev.movetype = MOVETYPE_NOCLIP;
			pPlayer.pev.solid = SOLID_NOT;
			pPlayer.pev.gamestate = 1;
			pPlayer.pev.effects |= EF_NODRAW;
			pPlayer.GetObserver().StartObserver( pPlayer.pev.origin, pPlayer.pev.angles, false );
			pPlayer.GetObserver().SetMode(OBS_ROAMING);
			pPlayer.GetObserver().SetObserverModeControlEnabled(true);
			pPlayer.SetMaxSpeedOverride( -1 );
		}
		else if(useType == USE_ON)
		{
			
		}
		else if(useType == USE_OFF)
		{
			
		}
	}
}

class CTriggerSortScore : ScriptBaseEntity
{
	int m_iSortType = 0;
	float m_flTriggerDelay = 0;
	string m_szFinalTarget = "";
	string m_szPitchSound = "";
	int m_iBasePitch = 100.0;
	int m_iAddPitch = 0.0;

	int m_iLastTriggerPlayerIndex = 0;
	int m_iTriggerPlayerCount = 0;
	USE_TYPE m_iLastUseType = USE_TOGGLE;
	float m_flEstFrags = 0;

	void Precache()
	{
		BaseClass.Precache();
		
		g_Game.PrecacheGeneric( "sound/" + m_szPitchSound );
		g_SoundSystem.PrecacheSound( m_szPitchSound );
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "sorttype"){
			m_iSortType = atoi(szValue);
			return true;
		}
		if(szKey == "delay"){
			m_flTriggerDelay = atof(szValue);
			return true;
		}
		if(szKey == "finaltarget"){
			m_szFinalTarget = szValue;
			return true;
		}
		if(szKey == "pitchsound"){
			m_szPitchSound = szValue;
			return true;
		}
		if(szKey == "basepitch"){
			m_iBasePitch = atoi(szValue);
			return true;
		}
		if(szKey == "addpitch"){
			m_iAddPitch = atoi(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Think()
	{
		if(m_flTriggerDelay > 0 && m_iLastTriggerPlayerIndex > 0)
		{
			for (int i = m_iLastTriggerPlayerIndex + 1; i <= g_Engine.maxClients; i++)
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
				if(pPlayer !is null && pPlayer.IsConnected())
				{
					if((m_iSortType == 0 && pPlayer.pev.frags == m_flEstFrags) ||
						(m_iSortType == 1 && pPlayer.pev.frags < m_flEstFrags)){
						
						g_EntityFuncs.FireTargets( self.pev.target, cast<CBaseEntity@>(@pPlayer), self, m_iLastUseType );

						if(m_szPitchSound != ""){
							int iPitch = (m_iBasePitch + m_iTriggerPlayerCount * m_iAddPitch);
							if(iPitch > 255)
								iPitch = 255;
							if(iPitch < 50)
								iPitch = 50;
							g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_STATIC, m_szPitchSound, 1.0, 0.01, 0, iPitch );
							//g_EntityFuncs.FireTargets( m_szPitchSound, cast<CBaseEntity@>(@pPlayer), self, USE_SET, flPitch);
						}

						//g_Game.AlertMessage( at_console, "Trigger player %1\n", pPlayer.pev.netname );
						
						m_iLastTriggerPlayerIndex = i;
						m_iTriggerPlayerCount ++;
						
						self.pev.nextthink = g_Engine.time + m_flTriggerDelay;
						return;
					}
					else if((m_iSortType == 2 && pPlayer.pev.frags == m_flEstFrags) ||
						(m_iSortType == 3 && pPlayer.pev.frags > m_flEstFrags)){
						
						g_EntityFuncs.FireTargets( self.pev.target, cast<CBaseEntity@>(@pPlayer), self, m_iLastUseType );
						
						if(m_szPitchSound != ""){
							int iPitch = (m_iBasePitch + m_iTriggerPlayerCount * m_iAddPitch);
							if(iPitch > 255)
								iPitch = 255;
							if(iPitch < 50)
								iPitch = 50;
							g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_STATIC, m_szPitchSound, 1.0, 0.01, 0, iPitch );
							//g_EntityFuncs.FireTargets( m_szPitchSound, cast<CBaseEntity@>(@pPlayer), self, USE_SET, flPitch);
						}

						m_iLastTriggerPlayerIndex = i;
						m_iTriggerPlayerCount ++;
						
						self.pev.nextthink = g_Engine.time + m_flTriggerDelay;
						return;
					}
				}
			}

			//No player found, end progress
			m_iLastTriggerPlayerIndex = 0;
			m_iTriggerPlayerCount = 0;

			if(m_szFinalTarget != "")
			{
				g_EntityFuncs.FireTargets( m_szFinalTarget, self, self, m_iLastUseType );
			}
		}
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		//Denied if in progress

		if(m_flTriggerDelay > 0 && m_iLastTriggerPlayerIndex > 0)
			return;

		if(m_iSortType == 0 || m_iSortType == 1)
		{
			float highestfrags = -99999.0;
			bool bFoundHighest = false;
			bool bHasNext = false;
			for (int i = 0; i <= g_Engine.maxClients; i++)
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
				if(pPlayer !is null && pPlayer.IsConnected())
				{
					if(!bFoundHighest || pPlayer.pev.frags > highestfrags){
						bFoundHighest = true;
						highestfrags = pPlayer.pev.frags;
					}
				}
			}
			
			if(bFoundHighest){

				m_flEstFrags = highestfrags;
				m_iLastUseType = useType;

				//g_Game.AlertMessage( at_console, "highestfrags - %1\n", highestfrags );

				for (int i = 0; i <= g_Engine.maxClients; i++)
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
					if(pPlayer !is null && pPlayer.IsConnected())
					{
						if((m_iSortType == 0 && pPlayer.pev.frags == highestfrags) || (m_iSortType == 1 && pPlayer.pev.frags < highestfrags))
						{
							g_EntityFuncs.FireTargets( self.pev.target, cast<CBaseEntity@>(@pPlayer), self, useType );

							if(m_szPitchSound != ""){
								int iPitch = (m_iBasePitch + m_iTriggerPlayerCount * m_iAddPitch);
								if(iPitch > 255)
									iPitch = 255;
								if(iPitch < 50)
									iPitch = 50;
								g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_STATIC, m_szPitchSound, 1.0, 0.01, 0, iPitch );
								//g_EntityFuncs.FireTargets( m_szPitchSound, cast<CBaseEntity@>(@pPlayer), self, USE_SET, flPitch);
							}
							
							m_iLastTriggerPlayerIndex = i;
							m_iTriggerPlayerCount ++;

							//g_Game.AlertMessage( at_console, "Trigger player %1\n", pPlayer.pev.netname );

							if(m_flTriggerDelay > 0){
								bHasNext = true;
								self.pev.nextthink = g_Engine.time + m_flTriggerDelay;
								return;
							}
						}
					}
				}

				if(!bHasNext && m_szFinalTarget != "")
				{
					g_EntityFuncs.FireTargets( m_szFinalTarget, self, self, useType );
				}
			}
		}
		else if(m_iSortType == 2 || m_iSortType == 3)
		{
			float lowestfrags = 99999.0;
			bool bFoundHighest = false;
			bool bHasNext = false;
			for (int i = 0; i <= g_Engine.maxClients; i++)
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
				if(pPlayer !is null && pPlayer.IsConnected())
				{
					if(!bFoundHighest || lowestfrags < pPlayer.pev.frags){
						bFoundHighest = true;
						lowestfrags = pPlayer.pev.frags;
					}
				}
			}
			
			if(bFoundHighest){

				m_flEstFrags = lowestfrags;
				m_iLastUseType = useType;

				for (int i = 0; i <= g_Engine.maxClients; i++)
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
					if(pPlayer !is null && pPlayer.IsConnected())
					{
						if((m_iSortType == 2 && pPlayer.pev.frags == lowestfrags) || (m_iSortType == 3 && pPlayer.pev.frags > lowestfrags))
						{
							g_EntityFuncs.FireTargets( self.pev.target, cast<CBaseEntity@>(@pPlayer), self, useType );
							
							if(m_szPitchSound != ""){
								int iPitch = (m_iBasePitch + m_iTriggerPlayerCount * m_iAddPitch);
								if(iPitch > 255)
									iPitch = 255;
								if(iPitch < 50)
									iPitch = 50;
								g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_STATIC, m_szPitchSound, 1.0, 0.01, 0, iPitch );
								//g_EntityFuncs.FireTargets( m_szPitchSound, cast<CBaseEntity@>(@pPlayer), self, USE_SET, flPitch);
							}

							m_iLastTriggerPlayerIndex = i;
							m_iTriggerPlayerCount ++;

							if(m_flTriggerDelay > 0){
								bHasNext = true;
								self.pev.nextthink = g_Engine.time + m_flTriggerDelay;
								return;
							}
						}
					}
				}

				if(!bHasNext && m_szFinalTarget != "")
				{
					g_EntityFuncs.FireTargets( m_szFinalTarget, self, self, useType );
				}
			}
		}
	}
}

class CTriggerRespawnUnstuck : ScriptBaseEntity
{
	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		g_PlayerFuncs.RespawnAllPlayers(true, true);

		array<CBaseEntity@> spawnpoints = {};
		array<CBasePlayer@> players = {};

		for (int i = 0; i <= g_Engine.maxClients; i++)
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
			if(pPlayer !is null && pPlayer.IsAlive())
			{
				players.insertLast(pPlayer);
			}
		}

		if(players.length() > 0)
		{
			CBaseEntity@ pEntity = null;
			while((@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "info_player_deathmatch")) !is null)
			{
				if(g_PlayerFuncs.IsSpawnPointValid(pEntity, players[0]))
				{
					spawnpoints.insertLast(pEntity);
				}
			}
		}

		for (int i = 0; i < int(players.length()); i++)
		{
			CBasePlayer@ pPlayer = players[i];
			if(spawnpoints.length() > 0)
			{
				int randomIndex = Math.RandomLong(0, spawnpoints.length() - 1);
				CBaseEntity@ pEntity = spawnpoints[randomIndex];

				g_EntityFuncs.SetOrigin(pPlayer, pEntity.pev.origin);
				pPlayer.pev.velocity = Vector(0, 0, 0);
				pPlayer.pev.angles = pEntity.pev.angles;

				spawnpoints.removeAt(randomIndex);
			}
			else
			{
				break;
			}
		}
	}
}

class CTriggerRotControl : ScriptBaseEntity
{
	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		//g_Game.AlertMessage( at_console, "Accelerating by %1, target %2\n", self.pev.targetname, self.pev.target);

		if(useType == USE_TOGGLE || useType == USE_ON)
		{
			g_EntityFuncs.FireTargets( self.pev.target, self, self, USE_SET, self.pev.speed );
		}
	}
}

class CTriggerRandomCounter : ScriptBaseEntity
{
	int m_iMinValue = 0;
	int m_iMaxValue = 1;
	array<string> m_szTargetArray = {};

	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "minvalue"){
			m_iMinValue = atoi(szValue);
			return true;
		}

		if(szKey == "maxvalue"){
			m_iMaxValue = atoi(szValue);
			return true;
		}

		if(szKey.StartsWith("target") && szKey != "targetname")
		{
			m_szTargetArray.insertLast(szValue);
		}
	
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if((self.pev.spawnflags & 1) == 1)
		{
			array<int> rnd( m_szTargetArray.length() );

			for (int i = 0; i < int(m_szTargetArray.length()); i++)
			{
				rnd[i] = (i % (1 + m_iMaxValue - m_iMinValue)) + m_iMinValue;
			}

			for (int i = int(m_szTargetArray.length()) - 1; i >= 0; i --) {
				int randomIndex = g_PlayerFuncs.SharedRandomLong( uint(g_Engine.time) + i, 0, i );//Math.RandomLong(0, i);
				int temp = rnd[randomIndex];
				rnd[randomIndex] = rnd[i];
				rnd[i] = temp;
			}

			for (int i = 0; i < int(m_szTargetArray.length()); i++)
			{
				g_EntityFuncs.FireTargets( m_szTargetArray[i], self, self, USE_SET, float(rnd[i]) );
				//g_Game.AlertMessage( at_console, "SetAverage %1 to %2\n", m_szTargetArray[i], float(rnd[i]) );
			}
		}
		else
		{
			for (int i = 0; i < int(m_szTargetArray.length()); i++)
			{
				int rnd = g_PlayerFuncs.SharedRandomLong( uint(g_Engine.time) + i, m_iMinValue, m_iMaxValue );
				g_EntityFuncs.FireTargets( m_szTargetArray[i], self, self, USE_SET, float(rnd) );
				//g_Game.AlertMessage( at_console, "Set %1 to %2\n", m_szTargetArray[i], float(rnd) );
			}
		}
	}
}

class CTriggerRandomMultiple : ScriptBaseEntity
{
	int m_iMinCount = 0;
	int m_iMaxCount = 1;
	array<string> m_szTargetArray = {};

	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "mincount"){
			m_iMinCount = atoi(szValue);
			return true;
		}

		if(szKey == "maxcount"){
			m_iMaxCount = atoi(szValue);
			return true;
		}

		if(szKey.StartsWith("target") && szKey != "targetname"&& szKey != "target_count")
		{
			m_szTargetArray.insertLast(szValue);
		}
	
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		array<int> rnd( m_szTargetArray.length() );

		for (int i = 0; i < int(m_szTargetArray.length()); i++)
		{
			rnd[i] = i;
		}

		for (int i = int(m_szTargetArray.length()) - 1; i >= 0; i --) {
			int randomIndex = g_PlayerFuncs.SharedRandomLong( uint(g_Engine.time) + i, 0, i );//Math.RandomLong(0, i);
			int temp = rnd[randomIndex];
			rnd[randomIndex] = rnd[i];
			rnd[i] = temp;
		}

		int count = g_PlayerFuncs.SharedRandomLong( uint(g_Engine.time), m_iMinCount, m_iMaxCount );

		for (int i = 0; i < count; i++)
		{
			g_EntityFuncs.FireTargets( m_szTargetArray[rnd[i]], self, self, useType, flValue );
			g_Game.AlertMessage( at_console, "TriggerRandom %1\n", m_szTargetArray[rnd[i]] );
		}
	}
}

class CTriggerEntityItor2 : ScriptBaseEntity
{
	string m_szNameStartWith = "";
	string m_szClassnameFilter = "";
	int m_iStatusFilter = 0;
	int m_iTriggerState = 0;

	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "classname_filter"){
			m_szClassnameFilter = szValue;
			return true;
		}

		if(szKey == "name_startwith"){
			m_szNameStartWith = szValue;
			return true;
		}

		if(szKey == "status_filter"){
			m_iStatusFilter = atoi(szValue);
			return true;
		}
	
		if(szKey == "triggerstate"){
			m_iTriggerState = atoi(szValue);
			return true;
		}
	
		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		CBaseEntity@ pTarget = g_EntityFuncs.FindEntityByTargetname(null, self.pev.target);
		if(pTarget !is null)
		{
			CBaseEntity@ pEntity = null;
			while((@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, m_szClassnameFilter)) !is null)
			{
				if( string(pEntity.pev.targetname).StartsWith(m_szNameStartWith)){

					if(m_iStatusFilter == 1 && pEntity.pev.deadflag != DEAD_NO)
						continue;
					else if(m_iStatusFilter == 2 && pEntity.pev.deadflag == DEAD_NO)
						continue;

					//!activator is not working with trigger_respawn so we have to redirect pev.target to targetname of found entities
					pTarget.pev.target = pEntity.pev.targetname;
					g_EntityFuncs.FireTargets( self.pev.target, pEntity, pEntity, USE_TYPE(m_iTriggerState) );
				}
			}
		}
	}
}

class CGamePlayerCounter2 : ScriptBaseEntity
{
	float m_flDelay = 1.0;

	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		NextThink(self.pev.ltime + 1.0, false);
		SetThink(ThinkFunction(this.CounterThink));
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "delay"){
			m_flDelay = atof(szValue);
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void NextThink(float thinkTime, const bool alwaysThink)
	{
		if (alwaysThink)
			self.pev.flags |= FL_ALWAYSTHINK;
		else
			self.pev.flags &= ~FL_ALWAYSTHINK;

		self.pev.nextthink = thinkTime;
	}

	void CounterThink()
	{
		self.pev.max_health = 0.0;
		self.pev.frags = 0.0;
		self.pev.armorvalue = 0.0;

		for (int i = 0; i <= g_Engine.maxClients; i++)
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
			if(pPlayer !is null && pPlayer.IsConnected())
			{
				self.pev.max_health += 1.0;
				if(pPlayer.IsAlive())
					self.pev.frags += 1.0;
				else
					self.pev.armorvalue += 1.0;
			}
		}

		if(m_flDelay > 0.0){
			NextThink(g_Engine.time + m_flDelay, false);
			SetThink(ThinkFunction(this.CounterThink));
		} else {
			NextThink(g_Engine.time + 0.0, true);
			SetThink(ThinkFunction(this.CounterThink));
		}
	}
}

class CTriggerFindBrush : ScriptBaseEntity
{
	string m_szFilterClassName = "";
	string m_szFilterTargetName = "";


	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_NOT;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		if(szKey == "filter_classname"){
			m_szFilterClassName = szValue;
			return true;
		}
		if(szKey == "filter_targetname"){
			m_szFilterTargetName = szValue;
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		Vector vecMins = self.pev.mins;
		Vector vecMaxs = self.pev.maxs;
		if((self.pev.spawnflags & 1) == 1){
			vecMins.x += pActivator.pev.origin.x;
			vecMins.y += pActivator.pev.origin.y;
			vecMins.z += pActivator.pev.origin.z;

			vecMaxs.x += pActivator.pev.origin.x;
			vecMaxs.y += pActivator.pev.origin.y;
			vecMaxs.z += pActivator.pev.origin.z;
		}

		//g_Game.AlertMessage( at_console, "Activator is %1 %2\n", pActivator.pev.netname, pActivator.pev.targetname);
		//g_Game.AlertMessage( at_console, "Search mins %1 %2 %3\n", vecMins.x, vecMins.y, vecMins.z );
		//g_Game.AlertMessage( at_console, "Search maxs %1 %2 %3\n", vecMaxs.x, vecMaxs.y, vecMaxs.z );

		array<CBaseEntity@> brushes( 32 );
    	int iNumBrushes = g_EntityFuncs.BrushEntsInBox( @brushes, vecMins, vecMaxs );

		if(iNumBrushes < 1)
			return;

		for (int i = 0; i < iNumBrushes; i++)
		{
			if(m_szFilterClassName != "")
			{
				if(brushes[i].pev.classname != m_szFilterClassName)
					continue;
			}

			if(m_szFilterTargetName != "")
			{
				if(brushes[i].pev.targetname != m_szFilterTargetName)
					continue;
			}

			g_EntityFuncs.FireTargets( self.pev.target, brushes[i], self, useType );

			g_Game.AlertMessage( at_console, "Triggering target %1\n", brushes[i].pev.classname);
		}
	}
}

class CTriggerFreeze : ScriptBaseEntity
{
	void Precache()
	{
		BaseClass.Precache();
	}

	void Spawn()
	{
		Precache();
		self.pev.solid = SOLID_TRIGGER;
		self.pev.movetype = MOVETYPE_NONE;

		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
	}

	bool KeyValue( const string & in szKey, const string & in szValue )
	{	
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Touch( CBaseEntity@ pOther )
	{
		if ( pOther is null || !pOther.IsPlayer() || !pOther.IsAlive())
			return;

		CBasePlayer@ pPlayer = cast<CBasePlayer@>(@pOther);
		if((self.pev.spawnflags & 1) == 1)
			pPlayer.SetMaxSpeedOverride(0);
		else
			pPlayer.SetMaxSpeedOverride(-1);
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if(useType == USE_TOGGLE)
		{
			if((self.pev.spawnflags & 1) == 1)
			{
				self.pev.spawnflags &= ~1;
				
				for (int i = 0; i <= g_Engine.maxClients; i++)
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
					if(pPlayer !is null && pPlayer.IsConnected())
					{
						pPlayer.SetMaxSpeedOverride(-1);
					}
				}
			}
			else
			{
				self.pev.spawnflags |= 1;
			}
		}
		else if(useType == USE_ON)
		{
			self.pev.spawnflags |= 1;
		}
		else if(useType == USE_OFF)
		{
			if((self.pev.spawnflags & 1) == 1)
			{
				self.pev.spawnflags &= ~1;
				
				for (int i = 0; i <= g_Engine.maxClients; i++)
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
					if(pPlayer !is null && pPlayer.IsConnected())
					{
						pPlayer.SetMaxSpeedOverride(-1);
					}
				}
			}
		}
		else if(useType == USE_SET)
		{
			if((self.pev.spawnflags & 1) == 1 && !(flValue > 0))
			{
				self.pev.spawnflags &= ~1;
				
				for (int i = 0; i <= g_Engine.maxClients; i++)
				{
					CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
					if(pPlayer !is null && pPlayer.IsConnected())
					{
						pPlayer.SetMaxSpeedOverride(-1);
					}
				}
			}
			else if((self.pev.spawnflags & 1) != 1 && (flValue > 0))
			{
				self.pev.spawnflags |= 1;
			}
		}
	}
}

HookReturnCode PlayerAddToFullPack( entity_state_t@ state, int e, edict_t @ent, edict_t@ host, int hostflags, int player, uint& out uiFlags )
{
	if(ent.vars.iuser4 == g_iLodStudioModelMagicNumber)
	{
		if(ent.vars.fuser1 > 0 && ent.vars.fuser2 > 0 && ent.vars.fuser3 > 0)
		{
			float distance = (ent.vars.origin - g_EngineFuncs.GetViewEntity(host).vars.origin).Length();

			state.body = 0;

			if(distance > ent.vars.fuser3){
				state.body = ent.vars.iuser3;
			}
			else if(distance > ent.vars.fuser2){
				state.body = ent.vars.iuser2;
			}
			else if(distance > ent.vars.fuser1){
				state.body = ent.vars.iuser1;
			}
		}
	}

	//Arrow Sprite
	if(ent.vars.iuser4 == g_iPlayerArrowSpriteMagicNumber)
	{
		if(ent.vars.iuser1 != g_EngineFuncs.IndexOfEdict(host))
		{
			//Hide other player's arrows
			uiFlags |= 1;
		}
		else
		{
			edict_t @viewEnt = g_EngineFuncs.GetViewEntity(host);
			if(@viewEnt == @host)
			{
				float distance = (ent.vars.origin - viewEnt.vars.origin).Length();

				if(distance > 1000.0)
				{
					state.modelindex = g_iPlayerArrowSprite2ModelIndex;
					state.scale = 0.75;
				}
				else if(distance > 300.0)
				{
					state.modelindex = g_iPlayerArrowSprite2ModelIndex;
					state.scale = 0.15 + 0.65 * (distance - 300.0) / 700.0;
				}
				else
				{
					state.scale = 0.15;
				}
			}
			else
			{
				float distance = (ent.vars.origin - viewEnt.vars.origin).Length();

				//trigger_camera or something
				if(distance > 1000.0)
				{
					state.modelindex = g_iPlayerArrowSprite2ModelIndex;
					state.scale = 0.75;
				}
				else if(distance > 600.0)
				{
					state.modelindex = g_iPlayerArrowSprite2ModelIndex;
					state.scale = 0.15 + 0.6 * (distance - 300.0) / 700.0;
				}
				else if(distance > 300.0)
				{
					state.modelindex = g_iPlayerArrowSprite2ModelIndex;
					state.scale = 0.15 + 0.6 * (distance - 300.0) / 700.0;
				}
				else
				{
					state.scale = 0.15;
				}
			}
		}
	}

    return HOOK_HANDLED;
}

const string m_szEliminatedSndName = "fallguys/eliminated.wav";

HookReturnCode PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
    if(pPlayer is null)
        return HOOK_HANDLED;
    if(!pPlayer.IsNetClient())
        return HOOK_HANDLED;
	
	NetworkMessage message( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
		message.WriteString("spk " + m_szEliminatedSndName+"\n");
	message.End();

	//MetaHookSv
	//NetworkMessage message( MSG_ONE, NetworkMessages::NetworkMessageType(146), pPlayer.edict() );
	//message.WriteByte(1);
	//message.End();

    return HOOK_HANDLED;
}

HookReturnCode PlayerSpawn(CBasePlayer@ pPlayer)
{
    if(pPlayer is null || !pPlayer.IsNetClient())
        return HOOK_CONTINUE;

	NetworkMessage message( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
		message.WriteString("thirdperson\n");
	message.End();

    return HOOK_CONTINUE;
}

HookReturnCode PlayerTakeDamage(DamageInfo@ info)
{
	//g_Game.AlertMessage( at_console, "takedamage from %1 %2\n", info.pAttacker.pev.netname, info.pAttacker.pev.targetname);
	if(info.pAttacker !is null && info.pAttacker.IsMonster())
	{
		CBaseMonster@ pMonster = cast<CBaseMonster@>(info.pAttacker);
		CBasePlayer@ pPlayer = cast<CBasePlayer@>(info.pVictim);

		if(pPlayer !is null && pPlayer.IsNetClient())
		{
			if(pMonster.pev.classname == "monster_bullchicken")
			{
				info.flDamage = 0;
				pPlayer.pev.punchangle.z = -20;
				pPlayer.pev.punchangle.x = 20;

				pPlayer.pev.velocity = pPlayer.pev.velocity + g_Engine.v_forward * (pMonster.pev.frags - 300);
				pPlayer.pev.velocity = pPlayer.pev.velocity + g_Engine.v_up * (pMonster.pev.armorvalue - 300);

				return HOOK_HANDLED;
			}
		}
	}
    return HOOK_CONTINUE;
}

HookReturnCode ClientPutInServer(CBasePlayer@ pPlayer)
{
	//svc_newusermsg = 39
	//NetworkMessage message( MSG_ONE, NetworkMessages::NetworkMessageType(39), pPlayer.edict() );
	//message.WriteByte(146);//64 ~ 145 = SelAmmo ~ VModelPos, all of them are reserved or used by Sven Co-op
	//message.WriteByte(255);//255 = variable length
	//message.WriteLong(0x6174654D);
	//message.WriteLong(0x6B6F6F48);
	//message.WriteLong(0);
	//message.WriteLong(0);
	//message.End();

	//g_Game.AlertMessage( at_console, "usermsg MetaHookSv registered for %1\n", pPlayer.pev.netname);
    return HOOK_CONTINUE;
}

void PlayerJump(CBasePlayer@ pPlayer)
{
	if ((pPlayer.pev.flags & FL_WATERJUMP) == FL_WATERJUMP)
		return;

	if (pPlayer.pev.waterlevel >= 2)
		return;

	if ((pPlayer.pev.flags & FL_ONGROUND) == 0)
		return;

	g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_VOICE, g_szPlayerJumpSound[Math.RandomLong(0, 7)], 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );
}

void PlayerFalling(CBasePlayer@ pPlayer)
{
	if(g_ArrayFallingPlayer[pPlayer.entindex()] == false){

		string szSoundName = g_szPlayerFallingSound[Math.RandomLong(0, 1)];

		//pPlayer.SetAnimation( PLAYER_JUMP );

		g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_VOICE, szSoundName, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );

		g_ArrayFallingPlayer[pPlayer.entindex()] = true;
		g_ArrayFallingPlayerPlayingSound[pPlayer.entindex()] = szSoundName;
	}
}

void PlayerStopFall(CBasePlayer@ pPlayer)
{
	if(g_ArrayFallingPlayer[pPlayer.entindex()] == true){

		g_SoundSystem.StopSound( pPlayer.edict(), CHAN_VOICE, g_ArrayFallingPlayerPlayingSound[pPlayer.entindex()] );

		g_ArrayFallingPlayer[pPlayer.entindex()] = false;
	}
}

void PlayerStopBlock(CBasePlayer@ pPlayer)
{
	g_ArrayBlockPlayer[pPlayer.entindex()].IsBlocking = false;

	if(g_ArrayBlockPlayer[pPlayer.entindex()].flLastSoundTime > 0 && 
		!g_ArrayBlockPlayer[pPlayer.entindex()].szPlayingSound.IsEmpty())
	{
		g_SoundSystem.StopSound( pPlayer.edict(), CHAN_BODY, g_ArrayBlockPlayer[pPlayer.entindex()].szPlayingSound );
		g_ArrayBlockPlayer[pPlayer.entindex()].flLastSoundTime = 0;
	}
}

void PlayerShowArrow(CBasePlayer@ pPlayer)
{
	EHandle eHandle = g_ArrayArrowEntityPlayer[pPlayer.entindex()];

	if(eHandle.IsValid())
		return;

	CBaseEntity@ pEntity = g_EntityFuncs.Create("info_target", pPlayer.pev.origin, pPlayer.pev.angles, false);
	g_EntityFuncs.SetModel(pEntity, g_szPlayerArrowSprite);
	pEntity.pev.sequence = 0;
	pEntity.pev.frame = 0;
	pEntity.pev.scale = 0.15;
	@pEntity.pev.aiment = pPlayer.edict();
	pEntity.pev.movetype = MOVETYPE_FOLLOW;
	pEntity.pev.rendermode = kRenderNormal;
	pEntity.pev.iuser4 = g_iPlayerArrowSpriteMagicNumber;
	pEntity.pev.iuser1 = pPlayer.entindex();

	//pEntity.pev.rendermode = kRenderGlow;
	//pEntity.pev.renderfx = kRenderFxNoDissipation;
	//pEntity.pev.rendercolor.x = 255;
	//pEntity.pev.rendercolor.y = 255;
	//pEntity.pev.rendercolor.z = 255;
	//pEntity.pev.renderamt = 255;
	
	g_ArrayArrowEntityPlayer[pPlayer.entindex()] = EHandle(@pEntity);
}

void PlayerHideArrow(CBasePlayer@ pPlayer)
{
	EHandle eHandle = g_ArrayArrowEntityPlayer[pPlayer.entindex()];

	if(!eHandle.IsValid())
		return;

	eHandle.GetEntity().SUB_Remove();
}

HookReturnCode PlayerPreThink(CBasePlayer@ pPlayer, uint& out uiFlags)
{
	if(pPlayer is null || !pPlayer.IsConnected())
		return HOOK_CONTINUE;

	if(pPlayer.IsAlive())
	{
		if((pPlayer.pev.button & IN_JUMP) == IN_JUMP && (pPlayer.pev.oldbuttons & IN_JUMP) == 0)
		{
			PlayerJump(pPlayer);
		}
	}

	return HOOK_CONTINUE;
}

HookReturnCode PlayerPostThink(CBasePlayer@ pPlayer)
{
	if(pPlayer is null || !pPlayer.IsConnected())
		return HOOK_CONTINUE;

	if(g_ArrayBlockPlayer[pPlayer.entindex()].IsBlocking &&
		g_Engine.time > g_ArrayBlockPlayer[pPlayer.entindex()].flLastBlockTime + 0.1)
	{
		PlayerStopBlock(pPlayer);
	}

	if(pPlayer.IsAlive())
	{
		PlayerShowArrow(pPlayer);
	}
	else
	{
		PlayerHideArrow(pPlayer);
	}

	if(pPlayer.IsAlive())
	{
		pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;

		if((pPlayer.pev.flags & FL_ONGROUND) == 0)
		{
			if(pPlayer.pev.velocity.z < -400.0)
			{
				PlayerFalling(pPlayer);
			}
		}
		else
		{
			PlayerStopFall(pPlayer);
		}
	}
	else
	{
		PlayerStopFall(pPlayer);
	}

    return HOOK_CONTINUE;
}

HookReturnCode PlayerPostThinkPost(CBasePlayer@ pPlayer)
{
	if(pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsAlive())
		return HOOK_CONTINUE;

	if(g_ArrayGrabPlayer[pPlayer.entindex()] != 0)
	{
		pPlayer.pev.sequence = 43;
		pPlayer.pev.frame = 100.0;
	}

    return HOOK_CONTINUE;
}

Vector GetViewDir(CBaseEntity@ plr) {
	Vector angles = plr.pev.v_angle;

	Math.MakeVectors( angles );
	
	return g_Engine.v_forward;
}

bool PlayerGrab( CBaseEntity@ pPlayer)
{	
	CBasePlayer@ pGrabber = cast<CBasePlayer@>(@pPlayer);

	Vector vecSrc = pGrabber.pev.origin;

	Vector dir = GetViewDir(pGrabber);
	
	Vector vecTarget = vecSrc + dir * 48.0;

	TraceResult tr;
	g_Utility.TraceHull( vecSrc, vecTarget, dont_ignore_monsters, head_hull, pGrabber.edict(), tr );

	CBaseEntity@ pHitEnt = g_EntityFuncs.Instance(tr.pHit);

	if(pHitEnt !is null and pHitEnt.IsMonster())
	{
		if(pHitEnt.entindex() != pGrabber.entindex())
		{
			if(pHitEnt.entindex() != g_ArrayGrabPlayer[pGrabber.entindex()])
			{
				g_ArrayGrabPlayer[pGrabber.entindex()] = pHitEnt.entindex();
				g_SoundSystem.EmitSoundDyn( pGrabber.edict(), CHAN_STATIC, g_szPlayerGrabSound, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );
			}

			Vector vDiff = vecTarget - pHitEnt.pev.origin;

			Vector vel = vDiff.Normalize() * 1200.0 * g_Engine.frametime;

			if(vel.z > 0.0)
				vel.z = 0.0;

			vel.z *= 0.1;

			pHitEnt.pev.velocity = pHitEnt.pev.velocity + vel;

			return true;
		}
	}

	return false;
}

HookReturnCode PlayerUse(CBasePlayer@ pPlayer, uint& out uiFlags)
{
	if(pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsAlive())
		return HOOK_CONTINUE;

	bool bGrabbing = false;

	if ((pPlayer.pev.button & IN_USE) == IN_USE)
	{
		bGrabbing = PlayerGrab(pPlayer);
	}

	if(!bGrabbing)
	{
		if(g_ArrayGrabPlayer[pPlayer.entindex()] != 0)
		{
			g_ArrayGrabPlayer[pPlayer.entindex()] = 0;
			g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_STATIC, g_szPlayerGrabReleaseSound, 1.0, 1.0, 0, 90 + Math.RandomLong(0, 20) );
		}
	}
	else
	{
		uiFlags |= PlrHook_SkipUse;
	}

    return HOOK_CONTINUE;
}

const bool doCommand(CBasePlayer@ plr, const CCommand@ args, bool inConsole) {

  if (args.ArgC() >= 2 && (args[0] == ".fgtest" || args[0] == "fgtest")) {

		CBaseEntity@ pEntity = null;
		while((@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "env_studiomodel")) !is null)
		{
			if(pEntity.pev.framerate == 0.0){
				pEntity.pev.frame = atof(args[1]);
			}
		}
		return true;
  }
  else if (args.ArgC() == 1 && (args[0] == ".fgtest" || args[0] == "fgtest")) {

		plr.pev.origin = Vector(-1923, -978, 1049);

		return true;
  }
  return false;
}


void consoleCmd(const CCommand@ args) {
  CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
  doCommand(plr, args, true);
}

CClientCommand _test("fgtest", "fgtest commands", @consoleCmd);

void MapInit()
{
	//Point entity
	g_CustomEntityFuncs.RegisterCustomEntity( "CEnvStudioModel", "env_studiomodel" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerHUDSprite", "trigger_hudsprite" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerHUDCountdown", "trigger_hudcountdown" );	
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRespawnUnstuck", "trigger_respawn_unstuck" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerSpectator", "trigger_spectator" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRotControl", "trigger_rot_control" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerSortScore", "trigger_sortscore" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRandomCounter", "trigger_random_counter" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRandomMultiple", "trigger_random_multiple" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerEntityItor2", "trigger_entity_itor2" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CGamePlayerCounter2", "game_player_counter2" );
	
	//Solid entity
	g_CustomEntityFuncs.RegisterCustomEntity( "CFuncRotatingFg", "func_rotating_fg" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CFuncTrackTrainFg", "func_tracktrain_fg" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CFuncTrainFg", "func_train_fg" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CFuncLever", "func_lever" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CFuncBarrier", "func_barrier" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CFuncBouncer", "func_bouncer" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerFreeze", "trigger_freeze" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerFindBrush", "trigger_findbrush" );

	g_iPlayerArrowSpriteModelIndex = g_Game.PrecacheModel( g_szPlayerArrowSprite );
	g_iPlayerArrowSprite2ModelIndex = g_Game.PrecacheModel( g_szPlayerArrowSprite2 );

	g_Game.PrecacheGeneric( "sound/" + m_szEliminatedSndName );

	g_SoundSystem.PrecacheSound( g_szPlayerGrabSound );
	g_SoundSystem.PrecacheSound( g_szPlayerGrabReleaseSound );

	g_szPlayerJumpSound[0] = "fallguys/playerjump1.ogg";
	g_szPlayerJumpSound[1] = "fallguys/playerjump2.ogg";
	g_szPlayerJumpSound[2] = "fallguys/playerjump3.ogg";
	g_szPlayerJumpSound[3] = "fallguys/playerjump4.ogg";
	g_szPlayerJumpSound[4] = "fallguys/playerjump5.ogg";
	g_szPlayerJumpSound[5] = "fallguys/playerjump6.ogg";
	g_szPlayerJumpSound[6] = "fallguys/playerjump7.ogg";
	g_szPlayerJumpSound[7] = "fallguys/playerjump8.ogg";

	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[0] );
	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[1] );
	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[2] );
	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[3] );
	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[4] );
	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[5] );
	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[6] );
	g_SoundSystem.PrecacheSound( g_szPlayerJumpSound[7] );

	g_szPlayerFallingSound[0] = "fallguys/playerfall1.ogg";
	g_szPlayerFallingSound[1] = "fallguys/playerfall2.ogg";

	g_SoundSystem.PrecacheSound( g_szPlayerFallingSound[0] );
	g_SoundSystem.PrecacheSound( g_szPlayerFallingSound[1] );

    g_Hooks.RegisterHook(Hooks::Player::PlayerAddToFullPack, @PlayerAddToFullPack);
	g_Hooks.RegisterHook(Hooks::Player::PlayerKilled, @PlayerKilled);
	g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);
    g_Hooks.RegisterHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
    g_Hooks.RegisterHook(Hooks::Player::PlayerPreThink, @PlayerPreThink);
    g_Hooks.RegisterHook(Hooks::Player::PlayerPostThink, @PlayerPostThink);
    g_Hooks.RegisterHook(Hooks::Player::PlayerPostThinkPost, @PlayerPostThinkPost);
    g_Hooks.RegisterHook(Hooks::Player::PlayerUse, @PlayerUse);
}

void PluginInit()
{
    g_Module.ScriptInfo.SetAuthor("hzqst");
    g_Module.ScriptInfo.SetContactInfo("Discord@hzqst#7626");
}