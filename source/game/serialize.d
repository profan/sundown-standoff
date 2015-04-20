module blindfire.serialize;

import blindfire.engine.gl;
import blindfire.engine.defs;
import blindfire.engine.net : NetVar;
import blindfire.engine.stream : InputStream;

import blindfire.sys;
import blindfire.action;
import profan.ecs;

enum networked = "networked";
enum ignore = "ignore";

template isAttribute(alias curAttr, alias Attr) {
	enum isAttribute = is(typeof(curAttr) == typeof(Attr)) && curAttr == Attr;
}

template hasAttribute(T, alias Member, alias Attribute, Attributes...) {

	static if (Attributes.length > 0 && isAttribute!(Attribute, Attributes[0])) {

		enum hasAttribute = true;

	} else static if (Attributes.length > 0) {

		enum hasAttribute = hasAttribute!(T, Member, Attribute, Attributes[1 .. $]);

	} else {

		enum hasAttribute = false;

	}

}

template getAttributes(T, alias Member) {
	enum getAttributes = __traits(getAttributes, __traits(getMember, T, Member));
}

template Identifier(alias Sym) {
	enum Identifier = __traits(identifier, Sym);
}

template StringIdentifier(alias T, alias Member) {
	enum StringIdentifier = typeof(Symbol!(T, Member)).stringof;
}

template Symbol(alias T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
}

template Symbol(T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
}

template isPOD(T) {
	enum isPOD = __traits(isPOD, T);
}

template NetVarToSym(T, alias Member) {
	enum NetVarToSym = Symbol!(T, Member).variable;
}

mixin template DoSerializable() {

	immutable ActionType type = ActionIdentifier[typeof(this).stringof];
	ActionType identifier() const {
		return type;
	}

	void serialize(ref StaticArray!(ubyte, 2048) buf) {
		mixin(MakeTypeSerializable!(typeof(this), typeof(this).tupleof));
	}

}

template MakeSerializable(Types...) {

	static if (Types.length > 0) {

		enum Type = Types[0].stringof;
		enum MakeSerializable = 
			"void serialize(StaticArray!(ubyte,2048) buf) {"
			~ MakeTypeSerializable!(Types[0], Types[0].tupleof) 
			~ "}" ~ MakeSerializable!(Types[1..$]);

	} else {

		enum MakeSerializable = "";

	}

}

template MakeTypeSerializable(T, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0].stringof))) {

		enum MakeTypeSerializable = AddSerialization!(T, members[0]) ~ MakeTypeSerializable!(T, members[1..$]);

	} else static if (members.length > 0) {

		enum MakeTypeSerializable = MakeTypeSerializable!(T, members[1..$]);

	} else {

		enum MakeTypeSerializable = "";

	}

}

template SizeString(alias Symbol) {

	enum SizeString = to!string(Symbol.sizeof);

}

template AddSerialization(T, alias Member) {

	enum AddSerialization = "buf ~= (cast(ubyte*)&" ~ Member.stringof ~ ")[0.."~SizeString!(Member)~"];";

}

template SerializeEachMember(T, alias data, alias object, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum SerializeEachMember =
			Identifier!(data) ~ " ~= " ~ Identifier!(object) ~ "." ~ members[0]
				~ SerializeEachMember!(T, data, object, members[1 .. $]);


	} else static if (members.length > 0) {

		enum SerializeEachMember = SerializeEachMember!(T, data, object, members[1 .. $]);

	} else {

		enum SerializeEachMember = "";

	}

}

template DeSerializeEachMember(T, alias data, alias object, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum DeSerializeEachMember = Identifier!(object) ~ "." ~ members[0] ~ " = " ~
				Identifier!(data) ~ ".read!(" ~ mixin("typeof("~Identifier!(object)~"."~members[0]~").stringof") ~ ")();" 
				~ DeSerializeEachMember!(T, data, object, members[1 .. $]);


	} else static if (members.length > 0) {

		enum DeSerializeEachMember = DeSerializeEachMember!(T, data, object, members[1 .. $]);

	} else {

		enum DeSerializeEachMember = "";

	}


}

//write identifier(type of component) and entity id, header of component message.
template WriteHeader(T, alias data, alias object) {
	enum WriteHeader =
		Identifier!(data) ~ " ~= " ~ Identifier!(object) ~ "." ~ "identifier_bytes;";
}

template ReadHeader() {
	enum ReadHeader = "";
}

template Serialize(T, alias data, alias object) {
	enum Serialize = SerializeEachMember!(T, data, object, T.tupleof);
}

template DeSerialize(T, alias data, alias object) {
	enum DeSerialize = DeSerializeEachMember!(T, data, object, __traits(allMembers, T)); //this is until the identifier shit is fix
}

template TotalNetSize(T, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum TotalNetSize = typeof(__traits(getMember, T, members[0]).bytes).sizeof + TotalNetSize!(T, members[1 .. $]);

	} else static if (members.length > 0) {

		enum TotalNetSize = TotalNetSize!(T, members[1 .. $]);

	} else {

		enum TotalNetSize = 0;

	}

}

template MemberSize(T) {
	enum MemberSize = TotalNetSize!(T, __traits(allMembers, T));
}

template DeSerializeAll(T, alias data, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum DeSerializeAll = 
			"case " ~ "ComponentIdentifier[" ~ T.stringof ~ "]: " ~
			"deserialize!" ~ StringIdentifier!(T, members[0]) ~ "(" ~ Identifier!(data) ~
			", components[entity_id]." ~ members[0] ~ "); break;" ~ DeSerializeAll!(T, data, members[1 .. $]);

	} else static if (members.length > 0) {

		enum DeSerializeAll = DeSerializeAll!(T, data, members[1 .. $]);

	} else {

		enum DeSerializeAll = "";

	}

}

string DeSerializeMembers(T, alias input_stream)() {

	string str = "";
	enum s = cast(T*)null;
	foreach (i, m; s.tupleof) {
	
		enum member = s.tupleof[i].stringof[8..$];
		alias typeof(m) type;
		static if (hasAttribute!(T, member, networked, getAttributes!(T, member))) {
			str ~= "case: ComponentIdentifier[" ~ T.stringof ~ "]:" ~
				"deserialize!" ~ type.stringof ~ "(" ~ Identifier!(input_stream) ~
				", components[entity_id]." ~ member ~ "); break;";
		}
	}

	return str;

}

mixin template DeSerializeMembers(T, alias data) {
	enum DeSerializeMembers = DeSerializeAll!(T, data, __traits(allMembers, T));
}

void serialize(B, T)(ref B data, T* object) {

	mixin Serialize!(T, data, object);
	mixin(Serialize);

}

void deserialize(T)(ref InputStream data, T* object) {

	mixin DeSerialize!(T, data, object);
	mixin(DeSerialize);

}
