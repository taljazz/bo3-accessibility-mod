#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;

// Pull in our accessibility mod
#using scripts\zm\zm_accessibility_main;

#insert scripts\shared\shared.gsh;

#namespace clientids;

REGISTER_SYSTEM( "clientids", &__init__, undefined )

function __init__()
{
    callback::on_start_gametype( &init );
    callback::on_connect( &on_player_connect );
}

function init()
{
    level.clientid = 0;
}

function on_player_connect()
{
    self.clientid = matchRecordNewPlayer( self );
    if ( !isdefined( self.clientid ) || self.clientid == -1 )
    {
        self.clientid = level.clientid;
        level.clientid++;
    }
}
