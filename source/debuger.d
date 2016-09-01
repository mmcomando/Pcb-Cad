/** This module provides ability to store data for debugging */
module debuger;
import std.stdio;
import std.conv:to;
import gl3n.linalg;
import std.algorithm:countUntil,canFind;


import core.thread:getpid;
import std.parallelism;
import core.atomic;

///Register thread local storage for global usage
static this(){
	synchronized(debugSynchronization){
		globalRoots~=&roots;
	}
}
///Deregister thread local storage
static ~this(){
	synchronized(debugSynchronization){
		foreach(i,gg;globalRoots){
			if(gg==&roots){
				globalRoots[i]=globalRoots[$-1];
				globalRoots=globalRoots[0..$-1];
			}
		}
	}
}


private class SynchronizationObject{}
///Global Object to synchronize access to globalRoots array
shared immutable debugSynchronization=new SynchronizationObject();
__gshared DebugRoot[]*[] globalRoots;

///Array to store data in given iteration
///Memory is reused

	alias ReusingArray=TypesContainer!(int,float,vec2);

///Debug data root with some additional data 
struct DebugRoot{
	ContainersGetter getter;///
	string rootName;///
	bool* enabler;///Pointer to enable or disable data acquisition by storage
	uint threadID;///
}





/**
 * Template to generate Universal shape
 */
struct TypesContainer(Types...) {
	alias FromTypes=Types;
	//enum types{...}    //from mixin
	//types currentType; //from mixin

	private ulong true_length;
	///Returns slice of data
	/**
	 * returns given type with check
	 */
	T[] get(T)(){
		foreach(i,type;FromTypes){
			static if(is(type==T)){
				assert(currentType==i,"got type which is not currently bound");
				mixin("return _"~i.to!string~"[0..true_length];");

			}
		}
		assert(false);
	}
	T[]* getWhole(T)(){
		foreach(i,type;FromTypes){
			currentType=cast(Types)i;
			static if(is(type==T)){
				mixin("return &_"~i.to!string~";");
				
			}
		}
		assert(false);
	}
	
	//  --  Mixin --
	/** 
	 * Generates code for universal shape
	 * types which can be packed to union are packed, others are allocated and there is stored their pointer
	 */
	static string getShapeCode(Types...)(){
		string codeChecks;
		string codeEnum="enum Types:ubyte{\n";
		string code="private union{\n";
		foreach(uint i,type;Types){
			string typeName=type.stringof;
			string valueName="_"~i.to!string;
			codeEnum~="_"~i.to!string~"="~i.to!string~",\n";
			code~= typeName~"[]";
			
			code~=" "~valueName~";\n";
			
			
		}
		codeEnum~="none\n}\n";
		return codeEnum~code~"}\n"~codeChecks~"Types currentType=Types.none;\n";
	}
	//pragma(msg,getShapeCode!(Types));
	mixin(getShapeCode!(Types));
}




///Container for data
///After warmup shouldn't allocate, don't reclaim memory
struct Container{
	string name;
	ReusingArray[] arr;//TODO MM replace with some vector not using GC, std.array uses GC.addRoot() so slows down another GC passes
	ulong iteration;

	void add(T)(T var){
		size_t len=arr.length;
		if(len<=iteration){
			arr.length=len+1;
		}
		ReusingArray* a=&arr[iteration];

		T[]* tab=a.getWhole!T;
		if(tab.length>a.true_length){
			(*tab)[a.true_length]=var;
			a.true_length++;
		}else{
			*tab~=var;
			a.true_length=tab.length;
		}
		
	}
	void reset(){
		foreach(ref ar;arr){
			ar.true_length=0;
		}
		iteration=0;
	}
	void next(){
		iteration++;
	}
}

///Due to usage of fancy templates we need inheritance(or delegates?) to get the Data from Debug storage objects
///Uset to return array of Containers
interface ContainersGetter{
	Container*[] get();
}
///Data getter for DebugImpl
class MyGetter(T):ContainersGetter{
	T* debugStruct;
	this(T* stru){
		debugStruct=stru;
	}
	Container*[] get(){
		Container*[] cons;
		foreach(ref var;debugStruct.containers){
			cons~=&var;
		}
		return cons;
	}
}
///Data getter for DebugCompileTime
class MyGetterCompileTime(T):ContainersGetter{
	T* debugStruct;
	this(T* stru){
		debugStruct=stru;
	}
	Container*[] get(){
		Container*[] cons;
		cons~=debugStruct.getContainersPointer();
		return cons;
	}
}


///Usefull alias with default fastKeys, saves some typing :P
alias Debug=DebugImpl!(["varA","varB","varC"]);
/**
 * Object which stores data using a key
 * Desired lookup for data is in that manner(due to the implementation its different but that's idea): 
 * 		my_int=[rootName][keyName][iterationNum][elementNum]
 * Uses DebugCompileTime to speed up few Keys
 */ 
struct DebugImpl(string[] fastKeyNamesParameter=[]){
	enum string[] fastKeyNames=fastKeyNamesParameter;
	enum hasCpContainer=fastKeyNamesParameter.length!=0;
	static if(hasCpContainer){
		DebugCompileTime!(fastKeyNames) cpDebugImpl;//cp=>compile time
	}

	Container[string] containers;
	string rootName;
	bool added_to_root;
	bool capture_data=true;

	///Construct object with name
	this(string name){
		this.rootName=name;
		static if(hasCpContainer){
			cpDebugImpl.rootName=name;
		}
	}
	///Adds this object to thread local registry for later access
	void init(){
		if(!added_to_root){
			initImpl();
		}
	}
	//Saves variable in container under given name
	void saveVar(string name,T)(T var){
		if(!capture_data)return;
		saveVarImpl!name(var);
	}
	///Resets data
	void reset(string name)(){
		if(!capture_data)return;
		Container* con=getContainer!name;
		con.reset();
	}
	///Moves container to next iteration
	void next(string name)(){
		if(!capture_data)return;
		Container* con=getContainer!name;
		con.next();
	}

	///Don't inline to host function(great speed up while not capturing data)
	private void saveVarImpl(string name,T)(T var){
		version(LDC){
			pragma(LDC_never_inline);
		}
		pragma(inline, false);//LDC won't listen to it
		Container* con=getContainer!name;
		con.add(var);
	}
	private void initImpl(){
		version(LDC){
			pragma(LDC_never_inline);
		}
		pragma(inline, false);
		added_to_root=true;
		addToShared(DebugRoot(new MyGetter!(typeof(this))(&this),rootName,&capture_data));
		static if(hasCpContainer){
			cpDebugImpl.init();
		}		
	}
	///Gets container for name
	private Container* getContainer(string name)(){
		static if(hasCpContainer && fastKeyNames.canFind(name)){
			return cpDebugImpl.getContainer!name;///For compile time keys there is no lookup cost
		}else{
			if(Container* con=name in containers){
				return con;
			}else{
				Container con;
				con.name=name;
				containers[name]=con;
				return &containers[name];
			}
		}
	}
}

/**
 * DebugImpl variation made for speed, no allocation and map lookup cost
 * Doc similar to  DebugImpl
 */
struct DebugCompileTime(string[] fastKeyNamesParameter){
	enum string[] fastKeyNames=fastKeyNamesParameter;
	
	Container[fastKeyNames.length] containers;
	Container*[fastKeyNames.length] containersPointer;
	
	string rootName;
	bool added_to_root;
	bool capture_data=true;
	
	Container*[fastKeyNames.length] getContainersPointer() {
		return containersPointer;
	}
	this(string name){
		this.rootName=name;
	}
	
	void init(){
		if(!added_to_root){
			added_to_root=true;
			addToShared(DebugRoot(new MyGetterCompileTime!(typeof(this))(&this),rootName,&capture_data));
			foreach(i,con;containers){
				containersPointer[i]=&containers[i];
				containers[i].name=fastKeyNames[i];
			}
		}
	}

	void saveVar(string name,T)(T var){
		if(!capture_data)return;
		Container* con=getContainer!name;
		con.add(var);
	}
	void reset(string name)(){
		if(!capture_data)return;
		Container* con=getContainer!name;
		con.reset();
	}
	void next(string name)(){
		if(!capture_data)return;
		Container* con=getContainer!name;
		con.next();
	}
	
	private Container* getContainer(string name)(){
		enum index=fastKeyNames.countUntil(name);
		static if(index!=-1){
			return &containers[index];		
		}else{
			assert(0,"Debug name not found in compile time debug");
		}
	}
}



// saves data under given name and creates storage with rootName
void ddd(string name,string rootName=__FUNCTION__,T)(T var){
	Debug* d=getDefaultDebug!(rootName);
	d.ddd!(name)(var);
}
void ddd(uint line=__LINE__,string rootName=__FUNCTION__,T)(T var){
	ddd!(to!string(line),rootName)(var);
}

// saves data under given name in storage
void ddd(string name,T,DD)(ref DD storage,T var){
	storage.saveVar!(name)(var);
}



/// Resets data under name
void dddReset(string name,string rootName=__FUNCTION__)(){
	Debug* d=getDefaultDebug!(rootName);
	d.dddReset!(name)();
}
void dddReset(string name)(Debug* deb){
	deb.reset!(name);
}
void dddReset(string name)(ref Debug deb){
	dddReset!(name)(&deb);
}


/// Makes variables under name to save in next array
void dddNext(string name,string rootName=__FUNCTION__)(){
	Debug* d=getDefaultDebug!(rootName);
	d.dddNext!(name)();
}
void dddNext(string name,DD)(ref DD deb){
	deb.next!(name);
}

void debugResetAll(){
	synchronized(debugSynchronization){
		foreach(DebugRoot[]* rootsLocal;globalRoots){
			foreach(ref DebugRoot root;*rootsLocal){
				foreach(Container* con;root.getter.get()){
					con.reset();
				}
			}
		}
	}
}
void debugResetThreadLocal(){
	foreach(ref DebugRoot root;roots){
		foreach(Container* con;root.getter.get()){
			con.reset();
		}
	}
}
Container*[] debugGetContainers(string rootName){
	Container*[] cons;

	synchronized(debugSynchronization){
		foreach(DebugRoot[]* rootsLocal;globalRoots){
			foreach(ref DebugRoot root;*rootsLocal){
				if(root.rootName!=rootName){
					continue;
				}
				foreach(Container* con;root.getter.get()){
					cons~=con;
				}
			}
		}
	}
	return cons;
}

void debugPrintContainer(){
	synchronized(debugSynchronization){
		foreach(DebugRoot[]* rootsLocal;globalRoots){
			foreach(ref DebugRoot root;*rootsLocal){
				writeln(root.rootName,root.threadID);
				foreach(Container* con;root.getter.get()){
					writeln(con.name);
					foreach(iii,ref ReusingArray arr;con.arr){
						write(iii," ");
						writeln(arr.get!vec2());
					}
				}
			}
		}
	}
}

private:
/**
 * Returns the same object for given name
 * Used to return the same Debug object in function
 */
Debug* getDefaultDebug(string name)(){
	static Debug d=Debug(name);
	d.init();
	return &d;
}
///Thread local roots
DebugRoot[] roots;

void addToShared(DebugRoot root){
	root.threadID=getpid;
	roots~=root;
	
}


///Simplest usage
///rootName is function name and key is line number
unittest{
	int factorial(int n){
		int res=1;
		foreach(i;1..n+1){
			ddd(i);
			res*=i;
		}
		ddd(res);
		return res;
	}
	factorial(4);
}
///Simplest usage with keys
///rootName is function name
unittest{
	int factorial(int n){
		int res=1;
		foreach(i;1..n+1){
			ddd!"i"(i);
			res*=i;
		}
		ddd!"result"(res);
		return res;
	}
	factorial(4);
}
///Usage with great performance with default fast keys
unittest{
	int factorial(int n){
		static auto d=Debug("Factorial Debug");// static!
		d.init();
		int res=1;
		foreach(i;1..n+1){
			d.ddd!"varA"(i);
			res*=i;
		}
		d.ddd!"varB"(res);
		return res;
	}
	factorial(4);
}
///Usage with great performance with custom fast keys
unittest{
	int factorial(int n){
		static auto d=DebugImpl!(["i","return"])("Factorial Debug");// static!
		d.init();
		int res=1;
		foreach(i;1..n+1){
			d.ddd!"i"(i);
			res*=i;
		}
		d.ddd!"return"(res);
		return res;
	}
	factorial(4);
}
/// control data capture, and make next iteration
unittest{
	int factorial(int n){
		static auto d=DebugImpl!(["i","return"])("Factorial Debug");// static!
		d.init();
		d.capture_data=false;
		int res=1;
		foreach(i;1..n+1){
			d.capture_data=i>1;
			d.ddd!"i"(i);
			d.dddNext!"i";
			res*=i;
		}
		d.ddd!"return"(res);
		return res;
	}
	factorial(4);
}