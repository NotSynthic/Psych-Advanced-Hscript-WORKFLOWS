package script;

import Type;
import flixel.FlxBasic;
import haxe.CallStack;
import haxe.Log;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import openfl.Lib;

using StringTools;

enum ScriptReturn
{
	PUASE;
	CONTINUE;
}

class Script extends FlxBasic
{
	public var variables(get, null):Map<String, Dynamic>;

	function get_variables()
		return _interp.variables;

	/**
	 *  The last Expr executed
	 *  Used for debugging
	 */
	public var ast(default, null):Expr;

	var _parser:Parser;
	var _interp:Interp;

	public var name:Null<String> = "_hscript";

	public var interacter:Interact;

	var _group:Null<ScriptGroup>;

	public function new()
	{
		super();

		_parser = new Parser();
		_parser.allowTypes = true;

		_interp = new Interp();

		interacter = new Interact(this);

		set("new", function() {});
		set("destroy", function() {});

		set("trace", Reflect.makeVarArgs(function(_)
		{
			Log.trace(Std.string(_.shift()), {
				lineNumber: _interp.posInfos() != null ? _interp.posInfos().lineNumber : -1,
				className: name,
				fileName: name,
				methodName: null,
				customParams: _.length > 0 ? _ : null
			});
		}));

		set("import", function(path:String, ?as:Null<String>)
		{
			try
			{
				if (path == null || path == "")
				{
					error("Path Not Specified!", '${name}:${getCurLine() != null ? Std.string(getCurLine()) : ''}: Import Error!');
					return;
				}

				var clas = Type.resolveClass(path); // ! class but without a s LMAO -lunar

				if (clas == null)
				{
					error('Class Not Found!\nPath: ${path}', '${name}:${getCurLine() != null ? Std.string(getCurLine()) : ''}: Import Error!');
					return;
				}

				var stringName:String = "";

				if (as != null)
					stringName = as;
				else
				{
					var arr = Std.string(clas).split(".");
					stringName = arr[arr.length - 1];
				}

				set(stringName, clas);
			}
			catch (e)
			{
				error('${e}', '${name}:${getCurLine() != null ? Std.string(getCurLine()) : ''}: Import Error!');
			}
		});

		set("ScriptReturn", ScriptReturn);
	}

	public inline function get(name:String):Dynamic
	{
		return _interp.variables.get(name);
	}

	public inline function set(name:String, val:Dynamic)
	{
		_interp.variables.set(name, val);
	}

	public function executeFunc(name:String, ?args:Null<Array<Any>>):Null<Dynamic>
	{
		try
		{
			if (_interp == null)
				return null;

			if (_interp.variables.exists(name) && get(name) != null)
			{
				var func = get(name);

				if (func != null && Reflect.isFunction(func))
				{
					if (args != null && args != [])
					{
						return Reflect.callMethod(null, func, args);
					}
					else
					{
						return func();
					}
				}
			}
			return null;
		}
		catch (e)
		{
			error('$e', '${name}:${getCurLine() != null ? Std.string(getCurLine()) : ''}: Function Error');
			return null;
		}
	}

	public function executeString(script:String):Dynamic
	{
		ast = parseScript(script);
		if (ast != null)
			return execute(ast);

		return null;
	}

	function parseScript(script:String):Null<Expr>
	{
		try
		{
			return _parser.parseString(script, name);
		}
		catch (e:Dynamic)
		{
			error('${name}:${_parser.line}: characters ${e.pmin} - ${e.pmax}: ${StringTools.replace(e,'${name}:${_parser.line}:', '')}',
				'${name}:${_parser.line}: Script Parser Error!');
			return null;
		}
	}

	public override function update(elapsed:Float)
	{
		/*
			 
			if (_interp != null)
			{
				@:privateAccess
				var curExpr:Expr = _interp.curExpr;

				if (lastExpr != curExpr)
				{
					lastExpr = curExpr;
					trace(lastExpr);
				}
			}
		 */

		super.update(elapsed);
	}

	function execute(ast:Expr):Dynamic
	{
		try
		{
			interacter.loadPresetVars();

			var val = _interp.execute(ast);
			executeFunc("new");

			interacter.upadteObj();

			return val;
		}
		catch (e:Dynamic)
		{
			error('$e \n${CallStack.toString(CallStack.exceptionStack())}');
		}
		return null;
	}

	public function error(errorMsg:String, ?winTitle:Null<String>)
	{
		trace(errorMsg);
		Lib.application.window.alert(errorMsg, winTitle != null ? winTitle : '${name}: Script Error!');
	}

	public override function destroy()
	{
		super.destroy();

		executeFunc("destroy");

		_interp = null;
		_parser = null;

		interacter.destroy();
		interacter = null;

		return null;
	}

	function getCurLine():Null<Int>
	{
		return _interp.posInfos() != null ? _interp.posInfos().lineNumber : null;
	}
}
