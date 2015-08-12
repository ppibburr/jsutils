using JSUtils;

namespace Bridge {
	public class Bridge : Binder {
		public weak Context context;
		public Bridge(Context c) {
			base("JSUtils");
			
			this.context = c;
			this.refer   = "JSUtils";
			this.iface_type = BinderType.MODULE;
			
			ValueType?[] vtypes = {ValueType.OBJECT};
			string[] vnames      = {"Array<String>"};
			
			bind("init_seed", (self, args, c, out e) => {
				if (ObjectType.from_object(c, (JSCore.Object)args[0]) != ObjectType.ARRAY) {
					raise(c, "Expects Array<String> as only argument", out e);
				}
				
				var vary = jsary2vary(c, (JSCore.Object)args[0]);
				string[] argv = new string[0];
				
				foreach(var a in vary) {
					argv += (string)a;
				}
				
				context.init_seed(argv);
				
				return true;
			}, 1, vtypes, vnames);
			
			bind("spawn", (self, args, c, out e) => {
				return false;
			});
			
			ValueType?[] r_types = {ValueType.STRING};
			string[]     r_names = {"String"};
			bind("require", (self, args, c, out e) => {
				var res = this.context.require((string)args[0]);
				
				if (res == null) {
					raise(c, "require: Could not find %s".printf((string)args[0]), out e);
					return null;
				}
				
				return (bool)res;
			}, 1, r_types, r_names);
			
			bind("exit", (self,args,c,out e) => {
				exit((int)(double)args[0]);
				return null;
			},1);
			
			bind("waitpid", (self, args, c, out e) => {
				if (value_type(args[0]) != ValueType.DOUBLE) {
					raise(c, "waitpid: Expects Integer as argument 1", out e);
					return null;
				}
				
				int es;
				int q;
				if (args.length == 1) {
					q = 0;
				} else {
					if (value_type(args[1]) != ValueType.DOUBLE) {
						raise(c, "waitpid: Expects Integer as argument 2", out e);
						return null;
					}
					
					q = (int)(double)args[1];
				}
				
				var pid = waitpid((Pid)(int)(double)args[0], q, out es);
				
				GLib.Value?[] o = new GLib.Value?[2];
				o[0] = (int)pid;
				o[1] = es;
				
				return new JSCore.Object.array(c, 2, vary2jary(c, o), out e);
			});
			
			ValueType?[] types = {ValueType.STRING};
			bind("load_so", (self, args, c, out e) => {
				if (null != context.load_so((string)args[0])) {
					return true;
				}
				
				return false;
			}, 1, types);
			
			bind("add_search_path", (s,args,c,out e) => {
				context.add_search_path((string)args[0]);
				return args[0];
			},1);
			
			bind("get_argv", (s,args,c, out e)=>{
				string[] argv = this.context.get_argv();
				GLib.Value?[] g = new GLib.Value?[0];
				foreach (var a in argv) {
					g += a;
				}
				
				return new JSCore.Object.array(c, argv.length, vary2jary(c, g), out e);
			});
			
			ValueType?[] sa_types = {ValueType.OBJECT};
			string[]    sa_names = {"Array<String>"};
			bind("set_argv", (self,args, c, out e)=>{
				var ary = jsary2vary(c, (JSCore.Object)args[0]);
				
				string[] argv = new string[0];
				
				foreach (var a in ary) {
					if (value_type(a) != ValueType.OBJECT || ObjectType.from_object(c, (JSCore.Object)a) != ObjectType.ARRAY) {
						raise(c, "Bad type for argv argument", out e);
						return null;
					}
					
					argv += (string)a;
				}
				
				this.context.set_argv(argv);
				
				return null;
			}, 1, sa_types, sa_names);			
			
			bind("get_file", ()=>{
				return this.context.get_file();
			});		
			
			ValueType?[] sf_types = {ValueType.STRING};
			string[]    sf_names = {"String"};
			bind("set_file", (self, args, c ,out e)=>{
				this.context.set_file((string)args[0]);
				
				return args[0];
			}, 1, sf_types, sf_names);					
			
			bind("get_env", ()=>{
				var env = this.context.get_env();
				
				var o = new JSUtils.Object(this.context, null, null);
				
				foreach (var pair in env) {
					var split = pair.split("=");
					GLib.Value? val = split[1];
					o.set_prop(context, split[0], val);
				}
				
				return o;
			});
			
			bind("set_variable", (self,args,c, out e) => {
				if (value_type(args[0]) != ValueType.STRING) {
					raise(c, "set_variable: Expects String as argument 1", out e);
					return null;
				}
				
				if (args[1] == null) {
					return this.context.set_variable((string)args[0], null);

				} else {
					if (value_type(args[1]) != ValueType.STRING) {
						raise(c, "set_variable: Expects String as argument 2", out e);
						return null;

					} else {
						this.context.set_variable((string)args[0], (string)args[1]);
						return args[1];
					}
				}
				
				return null;
			},2);			
			
			ValueType?[] gv_types = {ValueType.STRING};
			string[]    gv_names = {"String"};
			bind("get_variable", (self, args, c, out e) => {
				return this.context.get_variable((string)args[0]);
			}, 1, gv_types, gv_names);
			
			close();
		}
	}
	
	public class Console : Binder {
		public Console() {
			base("Console");
			
			this.refer = "Console";
			
			bind("log", (self,args, c, out e ) => {
				foreach(var a in args) {
					var str = v2str(a,c);
					if (str[str.length-1] != '\n') {
						str += "\n";
					}
					stdout.puts(str);
				}
				
				
				return null;
			});
			
			bind("warn", (self,args, c, out e) => {
				foreach(var a in args) {
					stderr.puts(v2str(a,c));
				}
				
				
				return null;
			});	
			
			close();		
		}
	}
	
	public static LibInfo? init(JSUtils.Context c) {
		var e = c.get_environment();
		e.environ = Environ.@get();
		e.file = "(file)";
		e.argv = {};
		
		LibInfo? lib_info = new LibInfo();
		var interfaces = new Binder?[0];

		var bridge  = new Bridge(c);
		bridge.create_toplevel_module(c);
		
		interfaces += bridge;
		
		var o = (JSUtils.Object)c.get_global_object();
		
		if (o.get_prop(c, "console") == null) {
			var console = new Console();
			c.add_toplevel_class(console);
			c.exec("var console = new Console();");
			interfaces += console;
		}
		
		lib_info.interfaces = interfaces;
		
		return lib_info;
		
	}
	
	[CCode (cname = "waitpid")] 
	extern Pid waitpid(Pid pid, int flags, out int status);	
}
