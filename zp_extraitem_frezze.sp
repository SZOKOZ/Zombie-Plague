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
    name            = "[ZP] ExtraItem: Freeze",
    author          = "qubka (Nikita Ushakov)",     
    description     = "Addon of extra items",
    version         = "1.0",
    url             = "https://forums.alliedmods.net/showthread.php?t=290657"
}

/**
 * @section Properties of the grenade.
 **/
#define GRENADE_FREEZE_TIME           4.0     // Freeze duration in seconds
#define GRENADE_FREEZE_RADIUS         200.0   // Freeze size (radius)
#define GRENADE_FREEZE_EXP_TIME       2.0     // Duration of the explosion effect in seconds
/**
 * @endsection
 **/
 
/**
 * @section Properties of the gibs shooter.
 **/
#define GLASS_GIBS_AMOUNT             5.0
#define GLASS_GIBS_DELAY              0.05
#define GLASS_GIBS_SPEED              500.0
#define GLASS_GIBS_VARIENCE           1.0  
#define GLASS_GIBS_LIFE               1.0  
#define GLASS_GIBS_DURATION           2.0
/**
 * @endsection
 **/
 
// Timer index
Handle Task_ZombieFreezed[MAXPLAYERS+1] = null; 

// Sound index
int gSound; ConVar hSoundLevel;
#pragma unused gSound, hSoundLevel

// Item index
int gItem; int gWeapon;
#pragma unused gItem, gWeapon

/**
 * @brief Called after a library is added that the current plugin references optionally. 
 *        A library is either a plugin name or extension name, as exposed via its include file.
 **/
public void OnLibraryAdded(const char[] sLibrary)
{
    // Validate library
    if(!strcmp(sLibrary, "zombieplague", false))
    {
        // Hook entity events
        HookEvent("smokegrenade_detonate", EventEntitySmoke, EventHookMode_Post);

        // Hooks server sounds
        AddNormalSoundHook(view_as<NormalSHook>(SoundsNormalHook));
    }
}

/**
 * @brief Called after a zombie core is loaded.
 **/
public void ZP_OnEngineExecute(/*void*/)
{
    // Items
    gItem = ZP_GetExtraItemNameID("freeze grenade");
    if(gItem == -1) SetFailState("[ZP] Custom extraitem ID from name : \"freeze grenade\" wasn't find");
    
    // Weapons
    gWeapon = ZP_GetWeaponNameID("freeze grenade");
    if(gWeapon == -1) SetFailState("[ZP] Custom weapon ID from name : \"freeze grenade\" wasn't find");

    // Sounds
    gSound = ZP_GetSoundKeyID("FREEZE_GRENADE_SOUNDS");
    if(gSound == -1) SetFailState("[ZP] Custom sound key ID from name : \"FREEZE_GRENADE_SOUNDS\" wasn't find");
   
    // Cvars
    hSoundLevel = FindConVar("zp_seffects_level");
    if(hSoundLevel == null) SetFailState("[ZP] Custom cvar key ID from name : \"zp_seffects_level\" wasn't find");
   
    // Models
    PrecacheModel("models/gibs/glass_shard01.mdl", true);
    PrecacheModel("models/gibs/glass_shard02.mdl", true);
    PrecacheModel("models/gibs/glass_shard03.mdl", true);
    PrecacheModel("models/gibs/glass_shard04.mdl", true);
    PrecacheModel("models/gibs/glass_shard05.mdl", true);
    PrecacheModel("models/gibs/glass_shard06.mdl", true);
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
        Task_ZombieFreezed[i] = null; /// with flag TIMER_FLAG_NO_MAPCHANGE
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
    delete Task_ZombieFreezed[clientIndex];
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
    delete Task_ZombieFreezed[clientIndex];
}

/**
 * @brief Called when a client became a zombie/human.
 * 
 * @param clientIndex       The client index.
 * @param attackerIndex     The attacker index.
 **/
public void ZP_OnClientUpdated(int clientIndex, int attackerIndex)
{
    // Reset move
    SetEntityMoveType(clientIndex, MOVETYPE_WALK);

    // Delete timer
    delete Task_ZombieFreezed[clientIndex];
}

/**
 * @brief Called before show an extraitem in the equipment menu.
 * 
 * @param clientIndex       The client index.
 * @param itemID            The item index.
 *
 * @return                  Plugin_Handled to disactivate showing and Plugin_Stop to disabled showing. Anything else
 *                              (like Plugin_Continue) to allow showing and calling the ZP_OnClientBuyExtraItem() forward.
 **/
public Action ZP_OnClientValidateExtraItem(int clientIndex, int itemID)
{
    // Check the item index
    if(itemID == gItem)
    {
        // Validate access
        if(ZP_IsPlayerHasWeapon(clientIndex, gWeapon) != INVALID_ENT_REFERENCE)
        {
            return Plugin_Handled;
        }
    }

    // Allow showing
    return Plugin_Continue;
}

/**
 * @brief Called after select an extraitem in the equipment menu.
 * 
 * @param clientIndex       The client index.
 * @param itemID            The item index.
 **/
public void ZP_OnClientBuyExtraItem(int clientIndex, int itemID)
{
    // Check the item index
    if(itemID == gItem)
    { 
        // Give item and select it
        ZP_GiveClientWeapon(clientIndex, gWeapon);
    }
}

/**
 * @brief Called when a client take a fake damage.
 * 
 * @param clientIndex       The client index.
 * @param attackerIndex     The attacker index.
 * @param inflictorIndex    The inflictor index.
 * @param damage            The amount of damage inflicted.
 * @param bits              The ditfield of damage types.
 * @param weaponIndex       The weapon index or -1 for unspecified.
 **/
public void ZP_OnClientDamaged(int clientIndex, int &attackerIndex, int &inflictorIndex, float &flDamage, int &iBits, int &weaponIndex)
{
    // If the client is frozen, then stop
    if(GetEntityMoveType(clientIndex) == MOVETYPE_NONE) flDamage = 0.0;
}

/**
 * Event callback (smokegrenade_detonate)
 * @brief The smokegrenade is exployed.
 * 
 * @param hEvent            The event handle.
 * @param sName             The name of the event.
 * @param dontBroadcast     If true, event is broadcasted to all clients, false if not.
 **/
public Action EventEntitySmoke(Event hEvent, char[] sName, bool dontBroadcast) 
{
    // Gets real player index from event key
    ///int ownerIndex = GetClientOfUserId(hEvent.GetInt("userid")); 

    // Initialize vectors
    static float vEntPosition[3]; static float vVictimPosition[3]; static float vVictimAngle[3];

    // Gets all required event info
    int grenadeIndex = hEvent.GetInt("entityid");
    vEntPosition[0] = hEvent.GetFloat("x"); 
    vEntPosition[1] = hEvent.GetFloat("y"); 
    vEntPosition[2] = hEvent.GetFloat("z");
    
    // Validate entity
    if(IsValidEdict(grenadeIndex))
    {
        // Validate custom grenade
        if(GetEntProp(grenadeIndex, Prop_Data, "m_iHammerID") == gWeapon)
        {
            // Find any players in the radius
            int i; int it = 1; /// iterator
            while((i = ZP_FindPlayerInSphere(it, vEntPosition, GRENADE_FREEZE_RADIUS)) != INVALID_ENT_REFERENCE)
            {
                // Skip humans
                if(ZP_IsPlayerHuman(i))
                {
                    continue;
                }
                
                // Freeze the client
                SetEntityMoveType(i, MOVETYPE_NONE);

                // Create an effect
                GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", vVictimPosition);
                UTIL_CreateParticle(i, vVictimPosition, _, _, "dynamic_smoke5", GRENADE_FREEZE_TIME+0.5);

                // Create timer for removing freezing
                delete Task_ZombieFreezed[i];
                Task_ZombieFreezed[i] = CreateTimer(GRENADE_FREEZE_TIME, ClientRemoveFreezeEffect, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);

                // Randomize pitch
                vVictimAngle[1] = GetRandomFloat(0.0, 360.0);
       
                // Create a prop_dynamic_override entity
                int iceIndex = UTIL_CreateDynamic("ice", vVictimPosition, vVictimAngle, "models/player/custom_player/zombie/ice/ice.mdl", "idle");

                // Validate entity
                if(iceIndex != INVALID_ENT_REFERENCE)
                {
                    // Kill after some duration
                    UTIL_RemoveEntity(iceIndex, GRENADE_FREEZE_TIME);
                    
                    // Play sound
                    ZP_EmitSoundToAll(gSound, 1, iceIndex, SNDCHAN_STATIC, hSoundLevel.IntValue);
                }
            }

            // Create an explosion effect
            UTIL_CreateParticle(_, vEntPosition, _, _, "explosion_hegrenade_snow", GRENADE_FREEZE_EXP_TIME);
            
            // Create sparks splash effect
            TE_SetupSparks(vEntPosition, NULL_VECTOR, 5000, 1000);
            TE_SendToAll();
            
            // Remove grenade
            AcceptEntityInput(grenadeIndex, "Kill");
        }
    }
}

/**
 * @brief Timer for the remove freeze effect.
 *
 * @param hTimer            The timer handle.
 * @param userID            The user id.
 **/
public Action ClientRemoveFreezeEffect(Handle hTimer, int userID)
{
    // Gets client index from the user ID
    int clientIndex = GetClientOfUserId(userID);
    
    // Clear timer 
    Task_ZombieFreezed[clientIndex] = null;

    // Validate client
    if(clientIndex)
    {
        // Initialize vectors
        static float vGibAngle[3]; float vShootAngle[3]; 

        // Unfreeze the client
        SetEntityMoveType(clientIndex, MOVETYPE_WALK);
        
        // Play sound
        ZP_EmitSoundToAll(gSound, 2, clientIndex, SNDCHAN_VOICE, hSoundLevel.IntValue);

        // Create a breaked glass effect
        static char sBuffer[NORMAL_LINE_LENGTH];
        for(int x = 0; x <= 5; x++)
        {
            // Find gib positions
            vShootAngle[1] += 60.0; vGibAngle[0] = GetRandomFloat(0.0, 360.0); vGibAngle[1] = GetRandomFloat(-15.0, 15.0); vGibAngle[2] = GetRandomFloat(-15.0, 15.0); switch(x)
            {
                case 0 : strcopy(sBuffer, sizeof(sBuffer), "models/gibs/glass_shard01.mdl");
                case 1 : strcopy(sBuffer, sizeof(sBuffer), "models/gibs/glass_shard02.mdl");
                case 2 : strcopy(sBuffer, sizeof(sBuffer), "models/gibs/glass_shard03.mdl");
                case 3 : strcopy(sBuffer, sizeof(sBuffer), "models/gibs/glass_shard04.mdl");
                case 4 : strcopy(sBuffer, sizeof(sBuffer), "models/gibs/glass_shard05.mdl");
                case 5 : strcopy(sBuffer, sizeof(sBuffer), "models/gibs/glass_shard06.mdl");
            }
        
            // Create gibs
            UTIL_CreateShooter(clientIndex, "eholster", _, MAT_GLASS, sBuffer, vShootAngle, vGibAngle, GLASS_GIBS_AMOUNT, GLASS_GIBS_DELAY, GLASS_GIBS_SPEED, GLASS_GIBS_VARIENCE, GLASS_GIBS_LIFE, GLASS_GIBS_DURATION);
        }
    }
    
    // Destroy timer
    return Plugin_Stop;
}

/**
 * @brief Called when a sound is going to be emitted to one or more clients. NOTICE: all params can be overwritten to modify the default behaviour.
 *  
 * @param clients           Array of client indexes.
 * @param numClients        Number of clients in the array (modify this value if you add/remove elements from the client array).
 * @param sSample           Sound file name relative to the "sounds" folder.
 * @param entityIndex       Entity emitting the sound.
 * @param iChannel          Channel emitting the sound.
 * @param flVolume          The sound volume.
 * @param iLevel            The sound level.
 * @param iPitch            The sound pitch.
 * @param iFlags            The sound flags.
 **/ 
public Action SoundsNormalHook(int clients[MAXPLAYERS-1], int &numClients, char[] sSample, int &entityIndex, int &iChannel, float &flVolume, int &iLevel, int &iPitch, int &iFlags)
{
    // Validate client
    if(IsValidEdict(entityIndex))
    {
        // Validate custom grenade
        if(GetEntProp(entityIndex, Prop_Data, "m_iHammerID") == gWeapon)
        {
            // Validate sound
            if(!strncmp(sSample[31], "hit", 3, false))
            {
                // Play sound
                ZP_EmitSoundToAll(gSound, GetRandomInt(4, 6), entityIndex, SNDCHAN_STATIC, hSoundLevel.IntValue);
                
                // Block sounds
                return Plugin_Stop; 
            }
            else if(!strncmp(sSample[29], "emit", 4, false))
            {
                // Play sound
                ZP_EmitSoundToAll(gSound, 3, entityIndex, SNDCHAN_STATIC, hSoundLevel.IntValue);
               
                // Block sounds
                return Plugin_Stop; 
            }
        }
    }
    
    // Allow sounds
    return Plugin_Continue;
}