module ppl.internal;

public:

import core.atomic     : atomicLoad, atomicStore;
import core.memory     : GC;
import core.sync.mutex : Mutex;

import std.stdio               : writefln, writeln;
import std.format              : format;
import std.string              : toLower, indexOf, lastIndexOf;
import std.conv                : to;
import std.array               : Appender, appender, array, join;
import std.range               : takeOne;
import std.json                : JSONValue, toJSON, JSONOptions;
import std.datetime.stopwatch  : StopWatch;

import std.algorithm.iteration : each, map, filter, sum;
import std.algorithm.searching : any, all, count, startsWith;
import std.algorithm.sorting   : sort;

import common : DynamicArray = Array;
import common : From, Hash, Hasher, Queue, Set, Stack, StringBuffer,
                as, dynamicDispatch, isA, firstNotNull, flushConsole, endsWith,
                putIfAbsent,
                removeChars, repeat, toInt, visit;

import llvm.all;
import ppl;

import ppl.Access;
import ppl.Attribute;
import ppl.CompileTimeConstant;
import ppl.Container;
import ppl.Mangler;
import ppl.ppl3;
import ppl.global;
import ppl.Operator;
import ppl.Target;

import ppl.ast.Parameters;
import ppl.ast.Placeholder;

import ppl.ast.expr.AddressOf;
import ppl.ast.expr.As;
import ppl.ast.expr.Binary;
import ppl.ast.expr.BuiltinFunc;
import ppl.ast.expr.Call;
import ppl.ast.expr.Calloc;
import ppl.ast.expr.Composite;
import ppl.ast.expr.Constructor;
import ppl.ast.expr.Dot;
import ppl.ast.expr.Expression;
import ppl.ast.expr.ExpressionRef;
import ppl.ast.expr.Identifier;
import ppl.ast.expr.If;
import ppl.ast.expr.Index;
import ppl.ast.expr.Initialiser;
import ppl.ast.expr.Is;
import ppl.ast.expr.Lambda;
import ppl.ast.expr.LiteralNumber;
import ppl.ast.expr.LiteralArray;
import ppl.ast.expr.LiteralFunction;
import ppl.ast.expr.LiteralMap;
import ppl.ast.expr.LiteralNull;
import ppl.ast.expr.LiteralString;
import ppl.ast.expr.LiteralTuple;
import ppl.ast.expr.ModuleAlias;
import ppl.ast.expr.Parenthesis;
import ppl.ast.expr.Select;
import ppl.ast.expr.TypeExpr;
import ppl.ast.expr.Unary;
import ppl.ast.expr.ValueOf;

import ppl.ast.stmt.Assert;
import ppl.ast.stmt.Break;
import ppl.ast.stmt.Continue;
import ppl.ast.stmt.Import;
import ppl.ast.stmt.Function;
import ppl.ast.stmt.Loop;
import ppl.ast.stmt.Return;
import ppl.ast.stmt.Statement;
import ppl.ast.stmt.Variable;

import ppl.build.BuildState;

import ppl.check.AfterSemantic;
import ppl.check.CheckModule;
import ppl.check.ControlFlow;
import ppl.check.EscapeAnalysis;

import ppl.error.CompilationAborted;
import ppl.error.CompileError;

import ppl.gen.GenerateBinary;
import ppl.gen.GenerateEnum;
import ppl.gen.GenerateFunction;
import ppl.gen.GenerateLiteral;
import ppl.gen.GenerateLoop;
import ppl.gen.GenerateIf;
import ppl.gen.GenerateModule;
import ppl.gen.GenerateSelect;
import ppl.gen.GenerateStruct;
import ppl.gen.GenerateVariable;

import ppl.misc.JsonWriter;
import ppl.misc.linker;
import ppl.misc.misc_logging;
import ppl.misc.node_builder;
import ppl.misc.optimiser;
import ppl.misc.util;
import ppl.misc.writer;

import ppl.parse.DetectType;
import ppl.parse.ParseAttribute;
import ppl.parse.ParseExpression;
import ppl.parse.ParseFunction;
import ppl.parse.ParseHelper;
import ppl.parse.ParseLiteral;
import ppl.parse.ParseModule;
import ppl.parse.ParseStruct;
import ppl.parse.ParseStatement;
import ppl.parse.ParseType;
import ppl.parse.ParseVariable;

import ppl.resolve.ResolveCalloc;
import ppl.resolve.ResolveAs;
import ppl.resolve.ResolveAlias;
import ppl.resolve.ResolveAssert;
import ppl.resolve.ResolveBinary;
import ppl.resolve.ResolveBuiltinFunc;
import ppl.resolve.ResolveCall;
import ppl.resolve.ResolveConstructor;
import ppl.resolve.ResolveEnum;
import ppl.resolve.ResolveIdentifier;
import ppl.resolve.ResolveIndex;
import ppl.resolve.ResolveIf;
import ppl.resolve.ResolveIs;
import ppl.resolve.ResolveLiteral;
import ppl.resolve.ResolveModule;
import ppl.resolve.ResolveSelect;
import ppl.resolve.ResolveUnary;
import ppl.resolve.ResolveVariable;

import ppl.resolve.misc.AfterResolution;
import ppl.resolve.misc.DeadCodeEliminator;
import ppl.resolve.misc.FoldUnreferenced;
import ppl.resolve.misc.FunctionFinder;
import ppl.resolve.misc.ImportFinder;
import ppl.resolve.misc.OverloadCollector;
import ppl.resolve.misc.TypeFinder;

import ppl.templates.blueprint;
import ppl.templates.ImplicitTemplates;
import ppl.templates.ParamTokens;
import ppl.templates.ParamTypeMatcherRegex;
import ppl.templates.templates;

import ppl.type.Alias;
import ppl.type.Array;
import ppl.type.Enum;
import ppl.type.Pointer;
import ppl.type.type;
import ppl.type.type_basic;
import ppl.type.type_function;
import ppl.type.Struct;
import ppl.type.Tuple;
