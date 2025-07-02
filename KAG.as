#include "Default/DefaultGUI.as"
#include "Default/DefaultLoaders.as"
#include "PrecacheTextures.as"
#include "EmotesCommon.as"

void onInit(CRules@ this)
{
	LoadDefaultMapLoaders();
	LoadDefaultGUI();

	// comment this out if you want to restore legacy net command script
	// compatibility. mods that include scripts from before build 4541 may
	// additionally want to bring back scripts they share commands with.
	getNet().legacy_cmd = false;

	if (isServer())
	{
		getSecurity().reloadSecurity();
	}

	sv_gravity = 0.0f;
	particles_gravity.y = 0.0f;
	sv_visiblity_scale = 2.0f;
	cc_halign = 2;
	cc_valign = 2;

	s_effects = false;
	sv_max_localplayers = 2;
	PrecacheTextures();

	//smooth shader
	Driver@ driver = getDriver();

	driver.AddShader("hq2x", 1.0f);
	driver.SetShader("hq2x", true);

	//reset var if you came from another gamemode that edits it
	SetGridMenusSize(24, 2.0f, 32);

	//also restart stuff
	onRestart(this);
}

bool need_sky_check = true;
void onRestart(CRules@ this)
{
	//map borders
	CMap@ map = getMap();
	if (map !is null)
	{
		map.SetBorderFadeWidth(0.0f);
		map.SetBorderColourTop(SColor(0x00000000));
		map.SetBorderColourLeft(SColor(0x00000000));
		map.SetBorderColourRight(SColor(0x00000000));
		map.SetBorderColourBottom(SColor(0x00000000));

		need_sky_check = true;
	}
}

void onTick(CRules@ this)
{
	if (need_sky_check)
	{
		need_sky_check = false;
		CMap@ map = getMap();

		bool has_solid_tiles = false;
		for(int i = 0; i < map.tilemapwidth; i++) {
			if(map.isTileSolid(map.getTile(i))) {
				has_solid_tiles = true;
				break;
			}
		}
		map.SetBorderColourTop(SColor(has_solid_tiles ? 0x00000000 : 0x00000000));
	}
}

//chat stuff!

void onEnterChat(CRules @this)
{
	if (getChatChannel() != 0) return; //no dots for team chat

	CBlob@ localblob = getLocalPlayerBlob();
	if (localblob !is null)
		set_emote(localblob, "dots", 100000);
}

void onExitChat(CRules @this)
{
	CBlob@ localblob = getLocalPlayerBlob();
	if (localblob !is null)
		set_emote(localblob, "", 0);
}
