
const int FL_ONGROUND = (1<<9);
const int FL_BASEVELOCITY = (1<<22);
const int SF_BRUSH_ACCDCC = 16;

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
		if(szKey == "inertia")
			m_flInertia = atof(szValue);
		if(szKey == "limitangle")
			m_flLimitAngle = atof(szValue);
		if(szKey == "limitbouncevelocity")
			m_flLimitBounceVelocity = atof(szValue);
		if(szKey == "limitbouncefriction")
			m_flLimitBounceFriction = atof(szValue);
		if(szKey == "returnangle")
			m_flReturnAngle = atof(szValue);
		if(szKey == "returnforce")
			m_flReturnForce = atof(szValue);
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
		if(szKey == "sprite")
		    m_szSprName = szValue;
		if(szKey == "framenum")
			m_nFrameNum = atoi(szValue);
		if(szKey == "holdtime")
			m_flHoldTime = atof(szValue);
		if(szKey == "sound")
		    m_szSoundName = szValue;
		if(szKey == "offsetx")
		    m_flOffsetX = atof(szValue);
		if(szKey == "offsety")
		    m_flOffsetY = atof(szValue);
		if(szKey == "channel")
		    m_iChannel = atoi(szValue);
		if(szKey == "sprwidth")
		    m_nSprWidth = atoi(szValue);
		if(szKey == "sprheight")
		    m_nSprHeight = atoi(szValue);

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
						message.WriteString("spk " + m_szSoundName);
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
								message.WriteString("spk " + m_szSoundName);
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
		if(szKey == "countnum")
			m_nCountNum = atoi(szValue);
		if(szKey == "offsetx")
		    m_flOffsetX = atof(szValue);
		if(szKey == "offsety")
		    m_flOffsetY = atof(szValue);
		if(szKey == "channel")
		    m_iChannel = atoi(szValue);

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
		if(szKey == "sorttype")
			m_iSortType = atoi(szValue);
		if(szKey == "delay")
			m_flTriggerDelay = atof(szValue);
		if(szKey == "finaltarget")
			m_szFinalTarget = szValue;
		if(szKey == "pitchsound")
			m_szPitchSound = szValue;
		if(szKey == "basepitch")
			m_iBasePitch = atoi(szValue);
		if(szKey == "addpitch")
			m_iAddPitch = atoi(szValue);

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

				g_Game.AlertMessage( at_console, "highestfrags - %1\n", highestfrags );

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
	float m_flNewSpeed = 0;

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
		if(szKey == "newspeed")
			m_flNewSpeed = atof(szValue);

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		g_Game.AlertMessage( at_console, "Accelerating by %1, target %2\n", self.pev.targetname, self.pev.target);

		if(useType == USE_TOGGLE || useType == USE_ON)
		{
			CBaseEntity@ pTarget = g_EntityFuncs.FindEntityByTargetname(null, self.pev.target);
			if(pTarget !is null)
			{
				if((pTarget.pev.spawnflags & SF_BRUSH_ACCDCC) == 0)
				{
					pTarget.pev.spawnflags |= SF_BRUSH_ACCDCC;
					pTarget.pev.speed = m_flNewSpeed;

					Vector saved_avelocity = pTarget.pev.avelocity;
					pTarget.pev.avelocity = Vector(0, 0, 0);
					
					g_Game.AlertMessage( at_console, "Accelerating for %1!\n", pTarget.pev.targetname);

					g_EntityFuncs.FireTargets( self.pev.target, self, self, USE_ON, flValue );

					pTarget.pev.avelocity = saved_avelocity;
					pTarget.pev.spawnflags &= ~SF_BRUSH_ACCDCC;
				}
				else
				{
					pTarget.pev.speed = m_flNewSpeed;

					Vector saved_avelocity = pTarget.pev.avelocity;
					pTarget.pev.avelocity = Vector(0, 0, 0);
					
					//g_Game.AlertMessage( at_console, "Accelerating for %1!\n", pTarget.pev.targetname);

					g_EntityFuncs.FireTargets( self.pev.target, self, self, USE_ON, flValue );

					pTarget.pev.avelocity = saved_avelocity;
				}
			}
		}
		else if(useType == USE_OFF)
		{
			CBaseEntity@ pTarget = g_EntityFuncs.FindEntityByTargetname(null, self.pev.target);
			if(pTarget !is null)
			{
				if((pTarget.pev.spawnflags & SF_BRUSH_ACCDCC) == 0)
				{
					pTarget.pev.spawnflags |= SF_BRUSH_ACCDCC;
					pTarget.pev.speed = pTarget.pev.frags;
					pTarget.pev.angles = Vector(0, 0, 0);
					g_EntityFuncs.FireTargets( self.pev.target, self, self, USE_OFF, flValue );

					pTarget.pev.spawnflags &= ~SF_BRUSH_ACCDCC;
				}
				else
				{
					pTarget.pev.speed = pTarget.pev.frags;
					pTarget.pev.angles = Vector(0, 0, 0);

					g_EntityFuncs.FireTargets( self.pev.target, self, self, USE_OFF, flValue );
				}
			}
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
		if(szKey == "minvalue")
			m_iMinValue = atoi(szValue);

		if(szKey == "maxvalue")
			m_iMaxValue = atoi(szValue);

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
		if(szKey == "mincount")
			m_iMinCount = atoi(szValue);

		if(szKey == "maxcount")
			m_iMaxCount = atoi(szValue);

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
		if(szKey == "filter_classname")
			m_szFilterClassName = szValue;
		if(szKey == "filter_targetname")
			m_szFilterTargetName = szValue;

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

		g_Game.AlertMessage( at_console, "Activator is %1 %2\n", pActivator.pev.netname, pActivator.pev.targetname);
		g_Game.AlertMessage( at_console, "Search mins %1 %2 %3\n", vecMins.x, vecMins.y, vecMins.z );
		g_Game.AlertMessage( at_console, "Search maxs %1 %2 %3\n", vecMaxs.x, vecMaxs.y, vecMaxs.z );

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

const string m_szEliminatedSndName = "fallguys/eliminated.wav";

HookReturnCode Killed( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
    if(pPlayer is null)
        return HOOK_HANDLED;
    if(!pPlayer.IsNetClient())
        return HOOK_HANDLED;
	
	NetworkMessage message( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
		message.WriteString("spk " + m_szEliminatedSndName);
	message.End();

    return HOOK_HANDLED;
}

HookReturnCode PlayerSpawn(CBasePlayer@ pPlayer)
{
    if(pPlayer is null || !pPlayer.IsNetClient())
        return HOOK_CONTINUE;

	NetworkMessage message( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
		message.WriteString("thirdperson");
	message.End();

    return HOOK_CONTINUE;
}

HookReturnCode PlayerTakeDamage(DamageInfo@ info)
{
	if(info.pAttacker !is null && info.pAttacker.IsMonster())
	{
		CBaseMonster@ pMonster = cast<CBaseMonster@>(info.pAttacker);
		CBasePlayer@ pPlayer = cast<CBasePlayer@>(info.pVictim);

		if(pPlayer !is null && pPlayer.IsNetClient())
		{
			//g_Game.AlertMessage( at_console, "PlayerTakeDamage %1\n", pMonster.pev.classname);
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

HookReturnCode PlayerPostThink(CBasePlayer@ pPlayer)
{
    if(pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsAlive())
        return HOOK_CONTINUE;

	pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;

    return HOOK_CONTINUE;
}

void MapInit()
{
	//Point entity
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerHUDSprite", "trigger_hudsprite" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerHUDCountdown", "trigger_hudcountdown" );	
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRespawnUnstuck", "trigger_respawn_unstuck" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRotControl", "trigger_rot_control" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerSortScore", "trigger_sortscore" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRandomCounter", "trigger_random_counter" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerRandomMultiple", "trigger_random_multiple" );
	
	//Solid entity
	g_CustomEntityFuncs.RegisterCustomEntity( "CFuncLever", "func_lever" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerFreeze", "trigger_freeze" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerFindBrush", "trigger_findbrush" );

	g_Game.PrecacheGeneric( "sound/" + m_szEliminatedSndName );
	
	g_Hooks.RegisterHook(Hooks::Player::PlayerKilled, @Killed);
	g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);
    g_Hooks.RegisterHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
    g_Hooks.RegisterHook(Hooks::Player::PlayerPostThink, @PlayerPostThink);
}

void PluginInit()
{
    g_Module.ScriptInfo.SetAuthor("hzqst");
    g_Module.ScriptInfo.SetContactInfo("Discord@hzqst#7626");
}