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