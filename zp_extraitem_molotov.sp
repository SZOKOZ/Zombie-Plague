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
    name            = "[ZP] ExtraItem: Molotov",
    author          = "qubka (Nikita Ushakov)",     
    description     = "Addon of extra items",
    version         = "1.0",
    url             = "https://forums.alliedmods.net/showthread.php?t=290657"
}

/**
 * @section Properties of the grenade.
 **/
#define GRENADE_IGNITE_DURATION        5.0     // Burning duration in seconds 
/**
 * @endsection
 **/

// Timer index
Handle Task_ZombieBurned[MAXPLAYERS+1] = null; float flSpeed[MAXPLAYERS+1]; int iD[MAXPLAYERS+1];
 
// Item index
int gItem; int gWeapon; int gDublicat;
#pragma unused gItem, gWeapon, gDublicat

/**
 * @brief Called after a zombie core is loaded.
 **/
public void ZP_OnEngineExecute(/*void*/)
{
    // Items
    gItem = ZP_GetExtraItemNameID("molotov");
    if(gItem == -1) SetFailState("[ZP] Custom extraitem ID from name : \"molotov\" wasn't find");
    
    // Weapons
    gWeapon = ZP_GetWeaponNameID("molotov");
    gDublicat = ZP_GetWeaponNameID("inc grenade"); /// Bugfix
    if(gWeapon == -1 || gDublicat == -1) SetFailState("[ZP] Custom weapon ID from name : \"molotov\" or \"inc grenade\" wasn't find");
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
        Task_ZombieBurned[i] = null; /// with flag TIMER_FLAG_NO_MAPCHANGE
    }
}

/**
 * @brief Called when a client is disconnecting from the server.
 *
 * @param clientIndex       The client index.
 **/
public void OnClientDisconnect(int clientIndex)
{
    // Reset variable
    flSpeed[clientIndex] = 0.0;
    
    // Delete timer
    delete Task_ZombieBurned[clientIndex];
}

/**
 * @brief Called when a client became a zombie/human.
 * 
 * @param clientIndex       The client index.
 * @param attackerIndex     The attacker index.
 **/
public void ZP_OnClientUpdated(int clientIndex, int attackerIndex)
{
    // Reset variable
    flSpeed[clientIndex] = 0.0;
    
    // Delete timer
    delete Task_ZombieBurned[clientIndex];
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
        if(ZP_IsPlayerHasWeapon(clientIndex, gWeapon) != INVALID_ENT_REFERENCE || 
           ZP_IsPlayerHasWeapon(clientIndex, gDublicat) != INVALID_ENT_REFERENCE)
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
 * @brief Called after a custom grenade is created.
 *
 * @param clientIndex       The client index.
 * @param grenadeIndex      The grenade index.
 * @param weaponID          The weapon id.
 **/
public void ZP_OnGrenadeCreated(int clientIndex, int grenadeIndex, int weaponID)
{   
    // Sets last grenade index
    iD[clientIndex] = (weaponID == gDublicat || weaponID == gWeapon) ? weaponID : -1;
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
    // Client was damaged by 'fire' or 'burn'
    if(iBits & DMG_BURN || iBits & DMG_DIRECT)
    {
        // Verify that the victim is zombie
        if(ZP_IsPlayerZombie(clientIndex))
        {
            // If the victim is in the water or freezed
            if(GetEntProp(clientIndex, Prop_Data, "m_nWaterLevel") > WLEVEL_CSGO_FEET || GetEntityMoveType(clientIndex) == MOVETYPE_NONE)
            {
                // This instead of 'ExtinguishEntity' function
                UTIL_ExtinguishEntity(clientIndex);
            }
            else
            {
                // Validate custom index
                static float flKnockBack = 1.0; static float flDuration;
                if(iD[clientIndex] == gDublicat)
                {
                    // Return damage multiplier
                    flDamage *= ZP_GetWeaponDamage(gDublicat);
                    
                    // Sets knockback
                    flKnockBack = ZP_GetWeaponKnockBack(gDublicat);
                    
                    // Sets duration
                    flDuration = ZP_GetWeaponModelHeat(gDublicat);
                }
                else if(iD[clientIndex] == gWeapon)
                {
                    // Return damage multiplier
                    flDamage *= ZP_GetWeaponDamage(gWeapon);
                    
                    // Sets knockback
                    flKnockBack = ZP_GetWeaponKnockBack(gWeapon);
                    
                    // Sets duration
                    flDuration = ZP_GetWeaponModelHeat(gWeapon);
                }
                else return;
                
                // Sets the last grenade index
                iD[clientIndex] = -1;
                
                // Put the fire on
                if(iBits & DMG_BURN) UTIL_IgniteEntity(clientIndex, flDuration);

                // Store the current speed
                if(!flSpeed[clientIndex]) flSpeed[clientIndex] = GetEntPropFloat(clientIndex, Prop_Data, "m_flLaggedMovementValue");

                // Sets a new speed
                SetEntPropFloat(clientIndex, Prop_Data, "m_flLaggedMovementValue", flSpeed[clientIndex] / flKnockBack);
                
                // Validate that timer not execute
                if(Task_ZombieBurned[clientIndex] == null)
                {
                    // Create timer for removing stopping
                    delete Task_ZombieBurned[clientIndex];
                    Task_ZombieBurned[clientIndex] = CreateTimer(1.0, ClientRemoveBurnEffect, GetClientUserId(clientIndex), TIMER_FLAG_NO_MAPCHANGE);
                }
                
                // Return on success
                return;
            }
        }
        
        // Block damage
        flDamage *= 0.0;
    }
}

/**
 * @brief Timer for remove burn effect.
 *
 * @param hTimer            The timer handle.
 * @param userID            The user id.
 **/
public Action ClientRemoveBurnEffect(Handle hTimer, int userID)
{
    // Gets client index from the user ID
    int clientIndex = GetClientOfUserId(userID);
    
    // Clear timer 
    Task_ZombieBurned[clientIndex] = null;

    // Validate client
    if(clientIndex)
    {    
        // Sets previous speed
        SetEntPropFloat(clientIndex, Prop_Data, "m_flLaggedMovementValue", flSpeed[clientIndex]);
    }
    
    // Reset variable
    flSpeed[clientIndex] = 0.0;

    // Destroy timer
    return Plugin_Stop;
}
