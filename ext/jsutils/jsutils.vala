using JSUtils;

namespace Bridge {
	public class Bridge : Binder {
		public weak Context context;
		public Bridge(Context c) {
			base("JSUtils");
			
			this.context = c;
			
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
			
			bind("waitpid", (self, args, c, out e) => {
				return false;
			});
			
			ValueType?[] types = {ValueType.STRING};
			bind("load_so", (self, args, c, out e) => {
				if (null != context.load_so((string)args[0])) {
					return true;
				}
				
				return false;
			}, 1, types);
			
			close();
		}
	}
	
	public class Console : Binder {
		public Console() {
			base("console");
			
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
	
	public static LibInfo? init(Context c) {
		var bridge  = new Bridge(c);
		bridge.create_toplevel_module(c);
		
		var console = new Console();
		console.create_toplevel_module(c);
		
		
		LibInfo? lib_info = new LibInfo();
		lib_info.interfaces = {bridge, console};
		
		return lib_info;
		
	}
}
