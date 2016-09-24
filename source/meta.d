module meta;
import std.algorithm:max;

import std.traits:isArray,ForeachType;

bool typeInTypes(TypeToCheck,TypesList...)(){
	bool isIn=false;
	foreach(Type;TypesList){
		static if (is(TypeToCheck == Type) ) {
			isIn=true;
		}
	}
	return isIn;
}

uint maxNestageLevel(T)(uint nestage=0){
	static if(is(T==struct) ||  is(T==class) ){
		uint maxNestage=nestage;
		foreach(i,Type; typeof(T.tupleof)) {
			maxNestage=max(maxNestage,maxNestageLevel!Type(nestage+1));
		}
		return maxNestage;
	}else static if(isArray!(T)){
		return max(nestage,maxNestageLevel!(ForeachType!(T))(nestage+1));
	}else{
		return nestage;
	}
}

uint numberOfVariables(T)(){
	uint num=0;
	static if(isArray!(T) && !isDynamicArray!T){
		num+=T.length;
	}else static if(is(T==struct) ||  is(T==class) ){
		enum  dummy=cast(T*)null;
		foreach(i,Type; typeof(T.tupleof)) {
			num+=numberOfVariables!Type;
		}
	}else{
		num++;
	}
	
	return num;
}

import std.conv:to;
import std.traits:hasMember,ReturnType,Parameters;
import std.meta:staticIndexOf;


/**
 * Union of ConTypes... 
 * Ensures correct access with assert
 */
struct SafeUnion(ConTypes...) {
	alias FromTypes=ConTypes;
	static assert(FromTypes.length>0,"Union has to have members.");
	//enum Types{...}    //from mixin
	//types currentType; //from mixin
	
	/**
	 * returns given type with check
	 */
	auto get(T)(){
		static assert(properType!T,"Given Type is not present in union");
		foreach(i,Type;FromTypes){
			static if(is(Type==T)){
				assert(currentType==i,"Got type which is not currently bound.");
				mixin("return &_"~i.to!string~";");
			}
		}
		assert(false);
	}
	/**
	 * Returns enum value for Type
	 */
	bool isType(T)(){
		static assert(properType!T,"Given Type is not present in union");
		bool ok=false;
		foreach(i,Type;FromTypes){
			static if(is(Type==T)){
				Types type=cast(Types)i;
				if(currentType==type){
					ok=true;
				}
			}
		}
		return ok;
	}
	/**
	 * Returns enum value for Type
	 */
	static Types getEnum(T)(){
		static assert(properType!T,"Given Type is not present in union");
		foreach(i,Type;FromTypes){
			static if(is(Type==T)){
				return cast(Types)i;
			}
		}
	}
	/**
	 * Sets given Type
	 */
	auto  set(T)(T obj){
		static assert(properType!T,"Given Type is not present in union");
		foreach(i,Type;FromTypes){
			static if(is(Type==T)){
				currentType=cast(Types)i;
				mixin("_"~i.to!string~"=obj;");
			}
		}
	}
	
	auto ref apply(alias fun)() {
		switch(currentType){
			mixin(getApplySwitch!(FromTypes));
			default:
				assert(0);
		}
	}
	
	/**
	 * Forwards call to union member
	 * Works only if all union members has this function and this function has the same return type and parameter types
	 */
	auto opDispatch(string funcName, Args...)(Args args){		
		foreach(Type;FromTypes){
			static assert(hasMember!(Type, funcName),"Every member of union have to implement '"~funcName~"' function.");
		}
		mixin("alias CompareReturnType=ReturnType!(FromTypes[0]."~funcName~");");
		mixin("alias CompareParametersTypes=Parameters!(FromTypes[0]."~funcName~");");
		foreach(Type;FromTypes){
			mixin("enum bool typeOk=is(ReturnType!(Type."~funcName~")==CompareReturnType);");
			mixin("enum bool parametersOk=is(Parameters!(Type."~funcName~")==CompareParametersTypes);");
			static assert(typeOk,"Return type "~CompareReturnType.stringof~" of '"~funcName~"' has to be the same in every union member.");
			static assert(parametersOk,"Parameter types "~CompareParametersTypes.stringof~" of '"~funcName~"' have to be the same in every union member.");
		}
		switch(currentType){
			mixin(getOpDispatchSwitch!(funcName,FromTypes));
			default:
				assert(0);
		}
	}
	
	//  --  Mixin --
	/** 
	 * Generates switch for opApply
	 */
	private static string getApplySwitch(FromTypes...)(){
		string str;
		foreach(uint i,type;FromTypes){
			string istr=i.to!string;
			str~="case Types._e_"~istr~":return fun(_"~istr~");\n";
		}
		return str;
	}
	/** 
	 * Generates switch for opDispatch
	 */
	private static string getOpDispatchSwitch(string funcName,FromTypes...)(){
		string str;
		foreach(uint i,type;FromTypes){
			string istr=i.to!string;
			str~="case Types._e_"~istr~":return _"~istr~"."~funcName~"(args);\n";
		}
		return str;
	}
	
	
	/** 
	 * Generates enum,and union with given FromTypes
	 */
	private static string getCode(FromTypes...)(){
		string codeEnum="enum Types:ubyte{\n";
		string code="private union{\n";
		foreach(uint i,type;FromTypes){
			string istr=i.to!string;
			string typeName=type.stringof;
			string enumName="_e_"~istr;
			string valueName="_"~istr;
			codeEnum~=enumName~"="~istr~",\n";
			code~="FromTypes["~istr~"] "~valueName~";\n";
			
			
		}
		codeEnum~="none\n}\n";
		return codeEnum~code~"}\nTypes currentType=Types.none;\n";
	}
	/**
	 *  Checks if Type is in union Types
	 */
	private static  bool properType(T)(){
		return staticIndexOf!(T,FromTypes)!=-1;
	}
	mixin(getCode!(FromTypes));
}
/// Example Usage
unittest{
	struct Triangle{		
		int add(int a){
			return a+10;
		}
	}
	struct Rectangle {
		int add(int a){
			return a+100;
		}
	}
	static uint strangeID(T)(T obj){
		static if(is(T==Triangle)){
			return 123;
		}else static if(is(T==Rectangle)){
			return 14342;			
		}else{
			assert(0);
		}
	}
	alias Shape=SafeUnion!(Triangle,Rectangle);
	Shape shp;
	shp.set(Triangle());
	assert(shp.isType!Triangle);
	assert(!shp.isType!Rectangle);
	assert(shp.add(6)==16);//Bad error messages if opDispatch!("add") cannot be instantiated
	assert(shp.opDispatch!("add")(6)==16);//Better error messages 
	assert(shp.apply!strangeID==123);
	//shp.get!(Rectangle);//Crash
	shp.set(Rectangle());
	assert(shp.add(6)==106);
	assert(shp.apply!strangeID==14342);
	shp.currentType=shp.Types.none;
	//shp.apply!strangeID;//Crash
	//shp.add(6);//Crash
	final switch(shp.currentType){
		case shp.getEnum!Triangle:
			break;
		case Shape.getEnum!Rectangle:
			break;
		case Shape.Types.none:
			break;
	}
}