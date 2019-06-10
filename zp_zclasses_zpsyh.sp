/**
 * ============================================================================
 *
 *  Zombie Plague
 *
 *
 *  Copyright (C) 2015-2019 Nikita Ushakov (Ireland, Dublin)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 **/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombieplague>

#pragma newdecls required

/**
 * @brief Record plugin info.
 **/
public Plugin myinfo =
{
    name            = "[ZP] Zombie Class: Psyh",
    author          = "qubka (Nikita Ushakov)",
    description     = "Addon of zombie classses",
    version         = "1.0",
    url             = "https://forums.alliedmods.net/showthread.php?t=290657"
}

/**
 * @section Information about the zombie class.
 **/    
#define ZOMBIE_CLASS_SKILL_RADIUS        250.0
#define ZOMBIE_CLASS_SKILL_DAMAGE        1.0
#define ZOMBIE_CLASS_SKILL_COLOR         {255, 0, 0, 200}
/**
 * @endsection
 **/

// Decal index
int decalTrail;
#pragma unused decalTrail

// Timer index
Handle Task_ZombieScream[MAXPLAYERS+1] = null; 

// Sound index
int gSound; ConVar hSoundLevel;
#pragma unused gSound, hSoundLevel
 
// Zombie index
int gZombie;
#pragma unused gZombie

/**
 * @brief Called after a zombie core is loaded.
 **/
public void ZP_OnEngineExecute(/*void*/)
{
    // Classes
    gZombie = ZP_GetClassNameID("psyh");
    if(gZombie == -1) SetFailState("[ZP] Custom zombie class ID from name : \"psyh\" wasn't find");
    
    // Sounds
    gSound = ZP_GetSoundKeyID("PSYH_SKILL_SOUNDS");
    if(gSound == -1) SetFailState("[ZP] Custom sound key ID from name : \"PSYH_SKILL_SOUNDS\" wasn't find");

    // Cvars
    hSoundLevel = FindConVar("zp_seffects_level");
    if(hSoundLevel == null) SetFailState("[ZP] Custom cvar key ID from name : \"zp_seffects_level\" wasn't find");
    
    // Models
    decalTrail = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}

/**
 * @brief The map is ending.
 **/
public void OnMapEnd(/*void*/)
{
    // i = client index
    for(int i = 1; i <= MaxClients; i++)
    {
        // Purge timer
        Task_ZombieScream[i] = null; /// with flag TIMER_FLAG_NO_MAPCHANGE
    }
}

/**
 * @brief Called when a client is disconnecting from the server.
 *
 * @param clientIndex       The client index.
 **/
public void OnClientDisconnect(int clientIndex)
{
    // Delete timer
    delete Task_ZombieScream[clientIndex];
}

/**
 * @brief Called when a client has been killed.
 * 
 * @param clientIndex       The client index.
 * @param attackerIndex     The attacker index.
 **/
public void ZP_OnClientDeath(int clientIndex, int attackerIndex)
{
    // Delete timer
    delete Task_ZombieScream[clientIndex];
}

/**
 * @brief Called when a client became a zombie/human.
 * 
 * @param clientIndex       The client index.
 * @param attackerIndex     The attacker index.
 **/
public void ZP_OnClientUpdated(int clientIndex, int attackerIndex)
{
    // Delete timer
    delete Task_ZombieScream[clientIndex];
}

/**
 * @brief Called when a client use a skill.
 * 
 * @param clientIndex       The client index.
 *
 * @return                  Plugin_Handled to block using skill. Anything else
 *                              (like Plugin_Continue) to allow use.
 **/
public Action ZP_OnClientSkillUsed(int clientIndex)
{
    // Validate the zombie class index
    if(ZP_GetClientClass(clientIndex) == gZombie)
    {
        // Create scream damage task
        delete Task_ZombieScream[clientIndex];
        Task_ZombieScream[clientIndex] = CreateTimer(0.1, ClientOnScreaming, GetClientUserId(clientIndex), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

        // Play sound
        ZP_EmitSoundToAll(gSound, 1, clientIndex, SNDCHAN_VOICE, hSoundLevel.IntValue);
        
        // Create effect
        static float vPosition[3];
        GetEntPropVector(clientIndex, Prop_Data, "m_vecAbsOrigin", vPosition);
        UTIL_CreateParticle(clientIndex, vPosition, _, _, "hell_end", ZP_GetClassSkillDuration(gZombie));
    }
    
    // Allow usage
    return Plugin_Continue;
}

/**
 * @brief Called when a skill duration is over.
 * 
 * @param clientIndex       The client index.
 **/
public void ZP_OnClientSkillOver(int clientIndex)
{
    // Validate the zombie class index
    if(ZP_GetClientClass(clientIndex) == gZombie) 
    {
        // Delete timer
        delete Task_ZombieScream[clientIndex];
    }
}

/**
 * @brief Timer for the screamming process.
 *
 * @param hTimer            The timer handle.
 * @param userID            The user id.
 **/
public Action ClientOnScreaming(Handle hTimer, int userID)
{
    // Gets client index from the user ID
    int clientIndex = GetClientOfUserId(userID);
    
    // Validate client
    if(clientIndex)
    {
        // Gets client origin
        static float vPosition[3];
        GetEntPropVector(clientIndex, Prop_Data, "m_vecAbsOrigin", vPosition); vPosition[2] += 25.0;  

        // Create the damage for victims
        UTIL_CreateDamage(_, vPosition, clientIndex, ZOMBIE_CLASS_SKILL_DAMAGE, ZOMBIE_CLASS_SKILL_RADIUS, DMG_SONIC);
            
        // Create a beamring effect               <Diameter>
        TE_SetupBeamRingPoint(vPosition, 50.0, ZOMBIE_CLASS_SKILL_RADIUS * 2.0, decalTrail, 0, 1, 10, 1.0, 15.0, 0.0, ZOMBIE_CLASS_SKILL_COLOR, 50, 0);
        TE_SendToAll();
        
        // Allow timer
        return Plugin_Continue;
    }

    // Clear timer
    Task_ZombieScream[clientIndex] = null;

    // Destroy timer
    return Plugin_Stop;
}
