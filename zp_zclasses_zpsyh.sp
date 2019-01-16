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
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
 * @section Information about zombie class.
 **/    
#define ZOMBIE_CLASS_SKILL_RADIUS        62500.0 // [squared]
#define ZOMBIE_CLASS_SKILL_DAMAGE        1.0 // 10 per second    
#define ZOMBIE_CLASS_SKILL_COLOR         {255, 0, 0, 200}
/**
 * @endsection
 **/

// Decal index
int decalTrail; int decalHalo;

// Timer index
Handle Task_ZombieScream[MAXPLAYERS+1] = null; 

// Sound index
int gSound; ConVar hSoundLevel;
#pragma unused gSound, hSoundLevel
 
// Zombie index
int gZombie;
#pragma unused gZombie

/**
 * @brief Called after a library is added that the current plugin references optionally. 
 *        A library is either a plugin name or extension name, as exposed via its include file.
 **/
public void OnLibraryAdded(const char[] sLibrary)
{
    // Validate library
    if(!strcmp(sLibrary, "zombieplague", false))
    {
        // Hook player events
        HookEvent("player_death", EventPlayerDeath, EventHookMode_Pre);
    }
}

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
    decalHalo  = PrecacheModel("materials/sprites/glow.vmt", true);  
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
 * Event callback (player_death)
 * @brief Client has been killed.
 * 
 * @param gEventHook        The event handle.
 * @param gEventName        The name of the event.
 * @param dontBroadcast     If true, event is broadcasted to all clients, false if not.
 **/
public Action EventPlayerDeath(Event hEvent, const char[] sName, bool dontBroadcast) 
{
    // Delete timer
    delete Task_ZombieScream[GetClientOfUserId(hEvent.GetInt("userid"))];
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

        // Emit sound
        static char sSound[PLATFORM_LINE_LENGTH];
        ZP_GetSound(gSound, sSound, sizeof(sSound));
        EmitSoundToAll(sSound, clientIndex, SNDCHAN_VOICE, hSoundLevel.IntValue);
        
        // Create effect
        static float vPosition[3];
        GetClientAbsOrigin(clientIndex, vPosition);
        ZP_CreateParticle(clientIndex, vPosition, _, "hell_end", ZP_GetClassSkillDuration(gZombie));
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
public Action ClientOnScreaming(Handle hTimer, const int userID)
{
    // Gets client index from the user ID
    int clientIndex = GetClientOfUserId(userID);
    
    // Validate client
    if(clientIndex)
    {
        // Initialize vectors
        static float vEntPosition[3]; static float vVictimPosition[3];

        // Gets client origin
        GetClientAbsOrigin(clientIndex, vEntPosition); vEntPosition[2] += 25.0;

        // i = client index
        for(int i = 1; i <= MaxClients; i++)
        {
            // Validate human
            if(IsPlayerExist(i) && ZP_IsPlayerHuman(i))
            {
                // Gets victim origin
                GetClientAbsOrigin(i, vVictimPosition);

                // Calculate the distance
                float flDistance = GetVectorDistance(vEntPosition, vVictimPosition, true);

                // Validate distance
                if(flDistance <= ZOMBIE_CLASS_SKILL_RADIUS)
                {            
                    // Apply damage
                    ZP_TakeDamage(i, clientIndex, ZOMBIE_CLASS_SKILL_DAMAGE * (1.0 - (flDistance / ZOMBIE_CLASS_SKILL_RADIUS)), DMG_SONIC);
                }
            }
        }

        // Create a beamring effect                                   <Diameter>
        TE_SetupBeamRingPoint(vEntPosition, 50.0, SquareRoot(ZOMBIE_CLASS_SKILL_RADIUS) * 2.0, decalTrail, decalHalo, 1, 10, 1.0, 15.0, 0.0, ZOMBIE_CLASS_SKILL_COLOR, 50, 0);
        TE_SendToAllInRange(vEntPosition, RangeType_Visibility);

        // Allow timer
        return Plugin_Continue;
    }

    // Clear timer
    Task_ZombieScream[clientIndex] = null;

    // Destroy timer
    return Plugin_Stop;
}