module schema2;

import std.array;
import std.meta;
import std.traits;
import std.typecons;
import std.algorithm : map, joiner;
import std.range : ElementEncodingType;
import std.format;
import std.string : strip;
import std.experimental.logger;

import vibe.data.json;

import helper;
import traits;

@safe:

enum GQLDKind {
	String,
	Float,
	Int,
	Bool,
	Object_,
	List,
	Enum,
	Map,
	Nullable,
	Union,
	Query,
	Mutation,
	Subscription,
	Schema
}

abstract class GQLDType(Con) {
	alias Context = Con;

	const GQLDKind kind;
	string name;

	this(GQLDKind kind) {
		this.kind = kind;
	}

	override string toString() const {
		return "GQLDType";
	}

	string toShortString() const {
		return this.toString();
	}
}

class GQLDScalar(Con) : GQLDType!(Con) {
	this(GQLDKind kind) {
		super(kind);
	}
}

class GQLDString(Con) : GQLDScalar!(Con) {
	this() {
		super(GQLDKind.String);
		super.name = "String";
	}

	override string toString() const {
		return "String";
	}
}

class GQLDFloat(Con) : GQLDScalar!(Con) {
	this() {
		super(GQLDKind.Float);
		super.name = "Float";
	}

	override string toString() const {
		return "Float";
	}
}

class GQLDInt(Con) : GQLDScalar!(Con) {
	this() {
		super(GQLDKind.Int);
		super.name = "Int";
	}

	override string toString() const {
		return "Int";
	}
}

class GQLDEnum(Con) : GQLDScalar!(Con) {
	string enumName;
	this(string enumName) {
		super(GQLDKind.Enum);
		this.enumName = enumName;
		super.name = enumName;
	}

	override string toString() const {
		return this.enumName;
	}
}

class GQLDBool(Con) : GQLDScalar!(Con) {
	this() {
		super(GQLDKind.Bool);
		super.name = "Bool";
	}

	override string toString() const {
		return "Bool";
	}
}

class GQLDMap(Con) : GQLDType!(Con) {
	GQLDType!(Con)[string] member;
	this() {
		super(GQLDKind.Map);
	}
	this(GQLDKind kind) {
		super(kind);
	}

	override string toString() const {
		auto app = appender!string();
		foreach(key, value; this.member) {
			formattedWrite(app, "%s: %s\n", key, value.toString());
		}
		return app.data;
	}
}

class GQLDObject(Con) : GQLDMap!(Con) {
	GQLDObject!(Con) _base;

	@property const(GQLDObject!(Con)) base() const {
		return cast(const)this._base;
	}

	@property void base(GQLDObject!(Con) nb) {
		this._base = nb;
	}

	this(string name) {
		super(GQLDKind.Object_);
		super.name = name;
	}

	override string toString() const {
		return format("Object %s(%s))\n\t\t\t\tBase(%s)",
				this.name,
				this.member
					.byKeyValue
					.map!(kv => format("%s %s", kv.key,
							kv.value.toShortString()))
					.joiner(",\n\t\t\t\t"),
				(this.base !is null ? this.base.toShortString() : "null")
			);
	}

	override string toShortString() const {
		return format("%s", super.name);
	}
}

class GQLDUnion(Con) : GQLDMap!(Con) {
	this(string name) {
		super(GQLDKind.Union);
		super.name = name;
	}

	override string toString() const {
		return format("Union %s(%s))",
				this.name,
				this.member
					.byKeyValue
					.map!(kv => format("%s %s", kv.key,
							kv.value.toShortString()))
					.joiner(",\n\t\t\t\t")
			);
	}
}

class GQLDList(Con) : GQLDType!(Con) {
	GQLDType!(Con) elementType;

	this(GQLDType!(Con) elemType) {
		super(GQLDKind.List);
		super.name = "List";
		this.elementType = elemType;
	}

	override string toString() const {
		return format("List(%s)", this.elementType.toShortString());
	}

	override string toShortString() const {
		return format("List(%s)", this.elementType.toShortString());
	}
}

class GQLDNullable(Con) : GQLDType!(Con) {
	GQLDType!(Con) elementType;

	this(GQLDType!(Con) elemType) {
		super(GQLDKind.Nullable);
		super.name = "Nullable";
		this.elementType = elemType;
	}

	override string toString() const {
		return format("Nullable(%s)", this.elementType.toShortString());
	}

	override string toShortString() const {
		return format("Nullable(%s)", this.elementType.toShortString());
	}
}

class GQLDOperation(Con) : GQLDType!(Con) {
	GQLDType!(Con) returnType;
	string returnTypeName;

	GQLDType!(Con)[string] parameters;

	this(GQLDKind kind) {
		super(kind);
	}

	override string toString() const {
		return format("%s %s(%s)", super.kind, returnType.toShortString(),
				this.parameters
					.byKeyValue
					.map!(kv =>
						format("%s %s", kv.key, kv.value.toShortString())
					)
					.joiner(", ")
				);
	}
}

class GQLDQuery(Con) : GQLDOperation!(Con) {
	this() {
		super(GQLDKind.Query);
		super.name = "Query";
	}
}

class GQLDMutation(Con) : GQLDOperation!(Con) {
	this() {
		super(GQLDKind.Mutation);
		super.name = "Mutation";
	}
}

class GQLDSubscription(Con) : GQLDOperation!(Con) {
	this() {
		super(GQLDKind.Subscription);
		super.name = "Subscription";
	}
}

class GQLDSchema(Type, Con) : GQLDMap!(Con) {
	GQLDType!(Con)[string] types;

	GQLDObject!(Con) __schema;
	GQLDObject!(Con) __type;
	GQLDObject!(Con) __field;
	GQLDObject!(Con) __inputValue;
	GQLDObject!(Con) __enumValue;

	GQLDList!(Con) __listType;
	GQLDList!(Con) __listField;
	GQLDList!(Con) __listInputValue;
	GQLDList!(Con) __listEnumValue;

	GQLDNullable!(Con) __nullableType;
	GQLDNullable!(Con) __nullableField;
	GQLDNullable!(Con) __nullableInputValue;

	GQLDList!(Con) __listNullableType;
	GQLDList!(Con) __listNullableField;
	GQLDList!(Con) __listNullableInputValue;

	GQLDNullable!(Con) __nullableListType;
	GQLDNullable!(Con) __nullableListField;
	GQLDNullable!(Con) __nullableListInputValue;

	GQLDNullable!(Con) __nullableListNullableType;
	GQLDNullable!(Con) __nullableListNullableField;
	GQLDNullable!(Con) __nullableListNullableInputValue;

	this() {
		super(GQLDKind.Schema);
		super.name = "Schema";
		this.createInbuildTypes();
		this.createIntrospectionTypes();
	}

	void createInbuildTypes() {
		foreach(t; ["String", "Int", "Float", "Bool"]) {
			GQLDObject!Con tmp = new GQLDObject!Con(t);
			this.types[t] = tmp;
			tmp.member["name"] = new GQLDString!Con();
			tmp.member["description"] = new GQLDString!Con();
			tmp.member["kind"] = new GQLDEnum!Con("__TypeKind");
			//tmp.resolver = buildTypeResolver!(Type,Con)();
		}
	}

	void createIntrospectionTypes() {
		// build base types
		this.__schema = new GQLDObject!Con("__schema");

		this.__type = new GQLDObject!Con("__type");
		this.__field = new GQLDObject!Con("__field");
		this.__inputValue = new GQLDObject!Con("__inputValue");
		this.__enumValue = new GQLDObject!Con("__enumValue");

		this.__listType = new GQLDList!Con(this.__type);
		this.__schema.member["__listType"] = this.__listType;
		this.__listField = new GQLDList!Con(this.__field);
		this.__listInputValue = new GQLDList!Con(this.__inputValue);
		this.__listEnumValue = new GQLDList!Con(this.__enumValue);

		this.__nullableType = new GQLDNullable!Con(this.__type);
		this.__schema.member["__nullType"] = this.__nullableType;
		this.__nullableField = new GQLDNullable!Con(this.__field);
		this.__nullableInputValue = new GQLDNullable!Con(this.__inputValue);

		this.__nullableListType = new GQLDNullable!Con(this.__listType);
		this.__nullableListField = new GQLDNullable!Con(this.__listField);
		this.__nullableListInputValue = new GQLDNullable!Con(
				this.__listInputValue
			);

		this.__listNullableType = new GQLDList!Con(this.__nullableType);
		this.__listNullableField = new GQLDList!Con(this.__nullableField);
		this.__listNullableInputValue =
				new GQLDList!Con(this.__nullableInputValue);

		this.__nullableListNullableType =
				new GQLDNullable!Con(this.__listNullableType);
		this.__nullableListNullableField =
				new GQLDNullable!Con(this.__listNullableField);
		this.__nullableListNullableInputValue =
				new GQLDNullable!Con(this.__listNullableInputValue);

		this.__schema.member["types"] = this.__listType;

		this.__type.member["name"] = new GQLDNullable!(Con)(
				new GQLDString!Con()
			);
		this.__type.member["description"] = new GQLDNullable!Con(
				new GQLDString!Con()
			);
		this.__type.member["fields"] = this.__nullableListField;
		this.__type.member["interfaces"] = this.__nullableListType;
		this.__type.member["possibleTypes"] = this.__nullableListType;
		this.__type.member["ofType"] = this.__nullableType;
		this.__type.member["kind"] = new GQLDEnum!Con("__TypeKind");

		this.__field.member["name"] = new GQLDString!Con();
		this.__field.member["description"] = new GQLDNullable!Con(
				new GQLDString!Con()
			);
		this.__field.member["type"] = this.__type;
		this.__field.member["isDeprecated"] = new GQLDBool!Con();
		this.__field.member["deprecatedReason"] = new GQLDNullable!Con(
				new GQLDString!Con()
			);

		foreach(t; ["String", "Int", "Float", "Bool"]) {
			this.types[t].toObject().member["fields"] = this.__nullableListField;
		}
	}

	override string toString() const {
		auto app = appender!string();
		formattedWrite(app, "Operation\n");
		foreach(key, value; super.member) {
			formattedWrite(app, "%s: %s\n", key, value.toString());
		}

		formattedWrite(app, "Types\n");
		foreach(key, value; this.types) {
			formattedWrite(app, "%s: %s\n", key, value.toString());
		}
		return app.data;
	}

	GQLDType!(Con) getReturnType(Con)(GQLDType!Con t, string field) {
		logf("'%s' '%s'", t.name, field);
		GQLDType!Con ret;
		if(auto s = t.toScalar()) {
			log();
			ret = s;
		} else if(auto op = t.toOperation()) {
			log();
			ret = op.returnType;
		} else if(auto map = t.toMap()) {
			if((map.name == "query" || map.name == "mutation"
						|| map.name == "subscription")
					&& field in map.member)
			{
				log();
				auto tmp = map.member[field];
				if(auto op = tmp.toOperation()) {
					log();
					ret = op.returnType;
				} else {
					log();
					ret = tmp;
				}
			} else if(field in map.member) {
				log();
				ret = map.member[field];
			} else {
				string[] k = map.member.byKey().array;
				logf("[%(%s, %)]", k);
				//logf("%s %s", t.toString(), field);
				return null;
			}
		} else {
			ret = t;
		}
		logf("%s", ret.name);
		return ret;
	}
}

GQLDSchema!(Con) toSchemaFoo(Con)(GQLDType!Con t) {
	return cast(typeof(return))t;
}

GQLDObject!(Con) toObject(Con)(GQLDType!Con t) {
	return cast(typeof(return))t;
}

GQLDMap!(Con) toMap(Con)(GQLDType!Con t) {
	return cast(typeof(return))t;
}

GQLDScalar!(Con) toScalar(Con)(GQLDType!Con t) {
	return cast(typeof(return))t;
}

GQLDOperation!(Con) toOperation(Con)(GQLDType!Con t) {
	return cast(typeof(return))t;
}

GQLDList!(Con) toList(Con)(GQLDType!Con t) {
	return cast(typeof(return))t;
}

GQLDNullable!(Con) toNullable(Con)(GQLDType!Con t) {
	return cast(typeof(return))t;
}

unittest {
	auto str = new GQLDString!(int)();
	assert(str.name == "String");

	auto map = str.toMap();
	assert(map is null);
}

string toShortString(Con)(const(GQLDType!(Con)) e) {
	if(auto o = cast(const(GQLDObject!(Con)))e) {
		return o.name;
	} else if(auto u = cast(const(GQLDUnion!(Con)))e) {
		return u.name;
	} else {
		return e.toString();
	}
}

template isNotObject(Type) {
	enum isNotObject = !is(Type == Object);
}

template collectTypesImpl(Type) {
	static if(is(Type == interface)) {
		alias tmp = AliasSeq!(collectReturnType!(Type,
				__traits(allMembers, Type))
			);
		alias collectTypesImpl = AliasSeq!(Type, tmp);
	} else static if(is(Type == class)) {
		alias mem = AliasSeq!(collectReturnType!(Type,
				__traits(allMembers, Type))
			);
		alias tmp = AliasSeq!(
				Fields!(Type),
				InheritedClasses!Type
			);
		alias collectTypesImpl = AliasSeq!(Type, tmp, mem);
	} else static if(is(Type == union)) {
		alias collectTypesImpl = AliasSeq!(Type, InheritedClasses!Type);
	} else static if(is(Type : Nullable!F, F)) {
		alias collectTypesImpl = .collectTypesImpl!(F);
	} else static if(isSomeString!Type) {
		alias collectTypesImpl = string;
	} else static if(is(Type == bool)) {
		alias collectTypesImpl = bool;
	} else static if(isArray!Type) {
		alias collectTypesImpl = .collectTypesImpl!(ElementEncodingType!Type);
	} else static if(isIntegral!Type) {
		alias collectTypesImpl = long;
	} else static if(isFloatingPoint!Type) {
		alias collectTypesImpl = float;
	} else {
		alias collectTypesImpl = AliasSeq!();
	}
}

template collectReturnType(Type, Names...) {
	static if(Names.length > 0) {
		static if(isCallable!(__traits(getMember, Type, Names[0]))) {
			alias collectReturnType = AliasSeq!(
					ReturnType!(__traits(getMember, Type, Names[0])),
					.collectReturnType!(Type, Names[1 .. $])
				);
		} else {
			alias collectReturnType = .collectReturnType!(Type, Names[1 .. $]);
		}
	} else {
		alias collectReturnType = AliasSeq!();
	}
}

template fixupBasicTypes(T) {
	static if(isSomeString!T) {
		alias fixupBasicTypes = string;
	} else static if(is(T == bool)) {
		alias fixupBasicTypes = bool;
	} else static if(isIntegral!T) {
		alias fixupBasicTypes = long;
	} else static if(isFloatingPoint!T) {
		alias fixupBasicTypes = float;
	} else static if(isArray!T) {
		alias ElemFix = fixupBasicTypes!(ElementEncodingType!T);
		alias fixupBasicTypes = ElemFix[];
	} else static if(is(T : Nullable!F, F)) {
		alias ElemFix = fixupBasicTypes!(F);
		alias fixupBasicTypes = Nullable!(ElemFix);
	} else {
		alias fixupBasicTypes = T;
	}
}

template noArrayOrNullable(T) {
	import std.typecons : Nullable;
	static if(is(T : Nullable!F, F)) {
		enum noArrayOrNullable = false;
	} else static if(!isSomeString!T && isArray!T) {
		enum noArrayOrNullable = false;
	} else {
		enum noArrayOrNullable = true;
	}
}

unittest {
	static assert(is(Nullable!int : Nullable!F, F));
	static assert(!is(int : Nullable!F, F));
	static assert( noArrayOrNullable!(int));
	static assert( noArrayOrNullable!(string));
	static assert(!noArrayOrNullable!(int[]));
	static assert(!noArrayOrNullable!(Nullable!int));
	static assert(!noArrayOrNullable!(Nullable!int));
}

template collectTypes(T...) {
	alias oneLevelDown = NoDuplicates!(staticMap!(collectTypesImpl, T));
	alias basicT = staticMap!(fixupBasicTypes, oneLevelDown);
	alias elemTypes = Filter!(noArrayOrNullable, basicT);
	alias rslt = NoDuplicates!(EraseAll!(Object, basicT),
			EraseAll!(Object, elemTypes)
		);
	static if(rslt.length == T.length) {
		alias collectTypes = rslt;
	} else {
		alias collectTypes = .collectTypes!(rslt);
	}
}

version(unittest) {
package {
	class U {
		string f;
		Bar bar;
	}
	class W {
		Nullable!(Nullable!(U)[]) us;
	}
	class Y {
		bool b;
		Nullable!W w;
	}
	class Z : Y {
		long id;
	}
	class Bar {
		string id;
		Z[] zs;
	}
	class Args {
		float value;
	}
	interface Foo {
		Bar bar();
		Args args();
	}
}
}

unittest {
	alias ts = collectTypes!(Foo);
	alias expectedTypes = AliasSeq!(Foo, Bar, Args, float, Z[], Z, string,
			long, Y, bool, Nullable!W, W, Nullable!(Nullable!(U)[]), U);

	template canBeFound(T) {
		enum tmp = staticIndexOf!(T, expectedTypes) != -1;
		enum canBeFound = tmp;
	}
	static assert(allSatisfy!(canBeFound, ts));
}

GQLDType!(Con) typeToGQLDType(Type, Con, SCH)(ref SCH ret) {
	pragma(msg, Type.stringof, " ", isIntegral!Type);
	static if(is(Type == bool)) {
		return new GQLDBool!(Con)();
	} else static if(isFloatingPoint!(Type)) {
		return new GQLDFloat!(Con)();
	} else static if(isIntegral!(Type)) {
		return new GQLDInt!(Con)();
	} else static if(isSomeString!Type) {
		return new GQLDString!(Con)();
	} else static if(is(Type == enum)) {
		GQLDEnum!(Con) r;
		if(Type.stringof in ret.types) {
			r = cast(GQLDEnum!(Con))ret.types[Type.stringof];
		} else {
			r = new GQLDEnum!(Con)();
			ret.types[Type.stringof] = r;
		}
		return r;
	} else static if(is(Type == union)) {
		GQLDUnion!(Con) r;
		if(Type.stringof in ret.types) {
			r = cast(GQLDUnion!(Con))ret.types[Type.stringof];
		} else {
			r = new GQLDUnion!(Con)(Type.stringof);
			ret.types[Type.stringof] = r;

			alias fieldNames = FieldNameTuple!(Type);
			alias fieldTypes = Fields!(Type);
			static foreach(idx; 0 .. fieldNames.length) {{
				r.member[fieldNames[idx]] =
					typeToGQLDType!(fieldTypes[idx], Con)(ret);
			}}
		}
		return r;
	} else static if(is(Type : Nullable!F, F)) {
		return new GQLDNullable!(Con)(typeToGQLDType!(F, Con)(ret));
	} else static if(isArray!Type) {
		return new GQLDList!(Con)(
				typeToGQLDType!(ElementEncodingType!Type, Con)(ret)
			);
	} else static if(isAggregateType!Type) {
		GQLDObject!(Con) r;
		if(Type.stringof in ret.types) {
			r = cast(GQLDObject!(Con))ret.types[Type.stringof];
		} else {
			r = new GQLDObject!(Con)(Type.stringof);
			ret.types[Type.stringof] = r;

			alias fieldNames = FieldNameTuple!(Type);
			alias fieldTypes = Fields!(Type);
			static foreach(idx; 0 .. fieldNames.length) {{
				r.member[fieldNames[idx]] =
					typeToGQLDType!(fieldTypes[idx], Con)(ret);
			}}

			alias bct = BaseClassesTuple!(Type);
			static if(bct.length > 1) {
				r.base = cast(GQLDObject!(Con))typeToGQLDType!(bct[0], Con)(ret);
			}
			assert(bct.length > 1 ? r.base !is null : true);
		}
		return r;
	} else {
		pragma(msg, "218 ", Type.stringof);
		static assert(false, Type.stringof);
	}
}

template stripArrayAndNullable(T) {
	static if(is(T : Nullable!F, F)) {
		alias stripArrayAndNullable = .stripArrayAndNullable!F;
	} else static if(!isSomeString!T && isArray!T) {
		alias stripArrayAndNullable =
			.stripArrayAndNullable!(ElementEncodingType!T);
	} else {
		alias stripArrayAndNullable = T;
	}
}

template typeToTypeEnum(Type) {
	static if(is(Type == bool)) {
		enum typeToTypeEnum = "SCALAR";
	} else static if(isFloatingPoint!(Type)) {
		enum typeToTypeEnum = "SCALAR";
	} else static if(isIntegral!(Type)) {
		enum typeToTypeEnum = "SCALAR";
	} else static if(isSomeString!Type) {
		enum typeToTypeEnum = "SCALAR";
	} else static if(is(Type == enum)) {
		enum typeToTypeEnum = "ENUM";
	} else static if(is(Type == union)) {
		enum typeToTypeEnum = "UNION";
	} else static if(is(Type : Nullable!F, F)) {
		enum typeToTypeEnum = "NULLABLE";
	} else static if(isArray!Type) {
		enum typeToTypeEnum = "LIST";
	} else static if(isAggregateType!Type) {
		enum typeToTypeEnum = "OBJECT";
	} else {
		static assert(false, T.stringof ~ " not handled");
	}
}

unittest {
	static assert(typeToTypeEnum!(int[]) == "LIST");
}

template typeToTypeName(Type) {
	static if(is(Type == bool)) {
		enum typeToTypeName = "Bool";
	} else static if(isFloatingPoint!(Type)) {
		enum typeToTypeName = "Float";
	} else static if(isIntegral!(Type)) {
		enum typeToTypeName = "Int";
	} else static if(isSomeString!Type) {
		enum typeToTypeName = "String";
	} else static if(isArray!Type) {
		enum typeToTypeName = "__listType";
	} else static if(is(Type : Nullable!F, F)) {
		enum typeToTypeName = "__nullType";
	} else {
		enum typeToTypeName = Type.stringof;
	}
}

unittest {
	static assert(typeToTypeName!(Nullable!int) == "__nullType");
}

template isScalarType(Type) {
	static if(is(Type == bool)) {
		enum isScalarType = true;
	} else static if(isFloatingPoint!(Type)) {
		enum isScalarType = true;
	} else static if(isIntegral!(Type)) {
		enum isScalarType = true;
	} else static if(isSomeString!Type) {
		enum isScalarType = true;
	} else static if(is(Type == enum)) {
		enum isScalarType = true;
	} else {
		enum isScalarType = false;
	}
}

Json typeToField(T, string name)() {
	alias Ts = stripArrayAndNullable!T;
	Json ret = Json.emptyObject();
	ret["name"] = name;
	ret["typename"] = typeToTypeName!(Ts);
	ret["typenameOrig"] = typeToTypeName!(T);
	ret["description"] = "TODO";
	ret["isDeprected"] = false;
	ret["deprecationReason"] = "TODO";
	return ret;
}

Json typeFields(T)() {
	import std.algorithm.searching : startsWith;
	import std.traits : FieldTypeTuple, FieldNameTuple;
	Json ret = Json.emptyArray();

	alias manyTypes = AliasSeq!(T, InheritedClasses!T);
	pragma(msg, "775 ", T.stringof, " ", manyTypes);
	static foreach(Type; manyTypes) {{
		alias fieldTypes = FieldTypeTuple!Type;
		alias fieldNames = FieldNameTuple!Type;
		static foreach(idx; 0 .. fieldTypes.length) {{
			static if(!fieldNames[idx].empty
					&& !startsWith(fieldNames[idx], "_"))
			{
				ret ~= typeToField!(fieldTypes[idx], fieldNames[idx]);
			}
		}}
	}}
	return ret;
}

Json emptyType() {
	Json ret = Json.emptyObject();
	ret["kind"] = "";
	ret["name"] = Json(null);
	ret["description"] = Json(null);
	ret["fields"] = Json(null);
	ret["interfacesNames"] = Json(null);
	ret["possibleTypesNames"] = Json(null);
	ret["ofTypeName"] = Json(null);
	ret["enumValues"] = Json(null);
	return ret;
}

Json typeToJson(Type)() {
	Json ret = Json.emptyObject();
	ret["kind"] = typeToTypeEnum!Type;
	ret["name"] = typeToTypeName!Type;
	ret["description"] = "TODO";

	// fields
	static if(is(Type == class) || is(Type == interface)) {
		ret["fields"] = typeFields!Type();
	} else {
		ret["fields"] = Json(null);
	}

	// needed to resolve interfaces
	static if(is(Type == class)) {
		ret["interfacesNames"] = Json.emptyArray();
		static foreach(interfaces; InheritedClasses!Type) {{
			ret["interfacesNames"] ~= interfaces.stringof;
		}}
	} else {
		ret["interfacesNames"] = Json(null);
	}

	// needed to resolve possibleTypes
	static if(is(Type == class) || is(Type == union)
			|| is(Type == interface))
	{
		ret["possibleTypesNames"] = Json.emptyArray();
		static foreach(pt; AliasSeq!(Type, InheritedClasses!Type)) {
			ret["possibleTypesNames"] ~= pt.stringof;
		}
	} else {
		ret["possibleTypesNames"] = Json(null);
	}

	// enumValues
	static if(is(Type == enum)) {
		ret["enumValues"] = Json.emptyArray();
		static foreach(mem; EnumMembers!Type) {
			ret["enumValues"] ~= Json(mem.stringof);
		}
	} else {
		ret["enumValues"] = Json(null);
	}

	// needed to resolve ofType
	static if(!isSomeString!Type && isArray!Type) {
		ret["ofTypeName"] = ElementEncodingType!(Type).stringof;
	} else static if(is(Type : Nullable!F, F)) {
		ret["ofTypeName"] = F.stringof;
	} else {
		ret["ofTypeName"] = Json(null);
	}

	return ret;
}

alias QueryResolver(Con) = Json delegate(string name, Json parent,
		Json args, ref Con context) @safe;

QueryResolver!(Con) buildSchemaResolver(Type, Con)() {
	QueryResolver!(Con) ret = delegate(string name, Json parent,
			Json args, ref Con context) @safe
		{
			//logf("%s %s %s", name, args, parent);
			Json ret = returnTemplate();
			ret["data"]["types"] = Json.emptyArray();
			pragma(msg, collectTypes!(Type));
			static foreach(type; collectTypes!(Type)) {{
				Json tmp = typeToJson!type();
				ret["data"]["types"] ~= tmp;
			}}
			return ret;
		};
	return ret;
}

QueryResolver!(Con) buildTypeResolver(Type, Con)() {
	QueryResolver!(Con) ret = delegate(string name, Json parent,
			Json args, ref Con context) @safe
		{
			logf("%s %s %s", name, args, parent);
			Json ret = returnTemplate();
			string typeName;
			if("name" in args) {
				typeName = args["name"].get!string();
			}
			if("typenameOrig" in parent) {
				typeName = parent["typenameOrig"].get!string();
			} else if("name" in parent) {
				typeName = parent["name"].get!string();
			}
			if(typeName.empty) {
				ret["error"] ~= Json(format("unknown type"));
				goto retLabel;
			}
			//logf("typeName %s", typeName);
			if(typeName == "__listType") {
				ret["data"] = typeToJson!(int[])();
				ret["data"]["typenameOrig"] = parent["typename"];
				ret["data"]["name"] = Json(null);
				goto retLabel;
			} else if(typeName == "__nullType") {
				ret["data"] = typeToJson!(Nullable!int)();
				ret["data"]["typenameOrig"] = parent["typename"];
				ret["data"]["name"] = Json(null);
				goto retLabel;
			}
			pragma(msg, collectTypes!(Type));
			static foreach(type; collectTypes!(Type)) {{
				string typeCap = firstCharUpperCase(typeName);
				enum typeConst = typeToTypeName!(type);
				if(typeCap == typeConst) {
					ret["data"] = typeToJson!type();
					logf("%s %s %s", typeCap, typeConst, ret["data"]);
					goto retLabel;
				} else {
					logf("||||||||||| %s %s", typeCap, typeConst);
				}
			}}
			retLabel:
			logf("%s", ret.toPrettyString());
			return ret;
		};
	return ret;
}

GQLDSchema!(Type, Con) toSchema2(Type, Con)() {
	typeof(return) ret = new typeof(return)();

	pragma(msg, __traits(allMembers, Type));
	static foreach(qms; ["query", "mutation", "subscription"]) {{
		GQLDMap!(Con) cur = new GQLDMap!Con();
		cur.name = qms;
		ret.member[qms] = cur;
		if(qms == "query") {
			cur.member["__schema"] = ret.__schema;
			cur.member["__type"] = ret.__type;
		}
		static assert(__traits(hasMember, Type, qms));
		alias QMSType = typeof(__traits(getMember, Type, qms));
		static foreach(mem; __traits(allMembers, QMSType)) {{
			alias MemType = typeof(__traits(getMember, QMSType, mem));
			static if(isCallable!(MemType)) {{
				GQLDOperation!(Con) op = qms == "query" ? new GQLDQuery!Con()
					: qms == "mutation" ? new GQLDMutation!Con()
					: qms == "subscription" ? new GQLDSubscription!Con()
					: null;
				cur.member[mem] = op;
				assert(op !is null);
				op.returnType = typeToGQLDType!(ReturnType!(MemType), Con)(ret);

				alias paraNames = ParameterIdentifierTuple!(
						__traits(getMember, QMSType, mem)
					);
				alias paraTypes = Parameters!(
						__traits(getMember, QMSType, mem)
					);
				static foreach(idx; 0 .. paraNames.length) {
					op.parameters[paraNames[idx]] =
						typeToGQLDType!(paraTypes[idx], Con)(ret);
				}
			}}
		}}
	}}
	return ret;
}

string toString(Con)(ref GQLDType!(Con)[string] all) {
	auto app = appender!string();
	foreach(key, value; all) {
		formattedWrite(app, "%20s: %s\n", key, value.toString());
	}
	return app.data;
}
