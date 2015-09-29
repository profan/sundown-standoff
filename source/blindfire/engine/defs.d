module blindfire.engine.defs;

import gfm.math : Vector, Matrix;

import blindfire.engine.event : Event, EventID, expandEventsToMap;
import blindfire.engine.ecs : EntityID;

//Network related
alias ClientID = ubyte;
alias LocalEntityID = ulong;

//OpenGL maths related
alias Vec2i = Vector!(int, 2);
alias Vec2f = Vector!(float, 2);
alias Vec3f = Vector!(float, 3);
alias Vec4f = Vector!(float, 4);
alias Mat3f = Matrix!(float, 3, 3);
alias Mat4f = Matrix!(float, 4, 4);

//rendering related
enum DrawEventType : EventID {

	RenderSprite,
	RenderLine

} //EventType

struct RenderSpriteCommand {
	import blindfire.engine.resource : ResourceID;

	immutable EntityID entity;
	immutable ResourceID resource;
	immutable Vec2i position;

	this(EntityID entity, ResourceID resource, Vec2i position) {

	}

} //RenderSpriteCommand

struct RenderLineCommand {

} //RenderLineCommand

alias RenderSpriteEvent = Event!(DrawEventType.RenderSprite, RenderSpriteCommand);

//networking related
enum ConnectionState {

	CONNECTED, //not accepting connections, active
	UNCONNECTED, //not accepting connections, can create
	CONNECTING //accepting connections, has created session or is in created lobby

} //ConnectionState

enum Command {

	//set network id
	ASSIGN_ID,

	CREATE,
	CONNECT,
	DISCONNECT,
	TERMINATE,
	UPDATE,
	PING,

	//replacement commands
	SET_CONNECTED,
	SET_UNCONNECTED,

	//notifications to game thread
	NOTIFY_CONNECTION

} //Command

enum NetEventType : EventID {
	AssignID,
	SetConnected,
	Disconnected,
	DoConnect,
	DoDisconnect,
	CreateGame,
	GameUpdate,
	SetConnectionStatus,
	ConnectionNotification
} //NetEventType

enum DisconnectReason : uint {
	HostDisconnected
} //DisconnectReason

alias AssignIDEvent = Event!(NetEventType.AssignID, ClientID);
alias IsConnectedEvent = Event!(NetEventType.SetConnected, bool);
alias DisconnectedEvent = Event!(NetEventType.Disconnected, DisconnectReason);
alias DoConnectEvent = Event!(NetEventType.DoConnect, bool);
alias DoDisconnectEvent = Event!(NetEventType.DoDisconnect, bool);
alias CreateGameEvent = Event!(NetEventType.CreateGame, bool);
alias GameUpdateEvent = Event!(NetEventType.GameUpdate, immutable(ubyte[]));
alias SetConnectionStatusEvent = Event!(NetEventType.SetConnectionStatus, ConnectionState);
alias ConnectionNotificationEvent = Event!(NetEventType.ConnectionNotification, ClientID);

mixin(expandEventsToMap!("NetEventIdentifier",
						 AssignIDEvent,
						 IsConnectedEvent,
						 DisconnectedEvent,
						 DoConnectEvent,
						 DoDisconnectEvent,
						 CreateGameEvent,
						 GameUpdateEvent,
						 SetConnectionStatusEvent,
						 ConnectionNotificationEvent));