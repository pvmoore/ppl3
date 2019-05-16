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

import ppl.ast.AddressOf;
import ppl.ast.As;
import ppl.ast.Assert;
import ppl.ast.Binary;
import ppl.ast.Break;
import ppl.ast.BuiltinFunc;
import ppl.ast.Call;
import ppl.ast.Calloc;
import ppl.ast.Composite;
import ppl.ast.Constructor;
import ppl.ast.Continue;
import ppl.ast.Dot;
import ppl.ast.Expression;
import ppl.ast.ExpressionRef;
import ppl.ast.Function;
import ppl.ast.Identifier;
import ppl.ast.If;
import ppl.ast.Import;
import ppl.ast.Index;
import ppl.ast.Initialiser;
import ppl.ast.Is;
import ppl.ast.Lambda;
import ppl.ast.LiteralNumber;
import ppl.ast.LiteralArray;
import ppl.ast.LiteralFunction;
import ppl.ast.LiteralMap;
import ppl.ast.LiteralNull;
import ppl.ast.LiteralString;
import ppl.ast.LiteralTuple;
import ppl.ast.Loop;
import ppl.ast.ModuleAlias;
import ppl.ast.Parameters;
import ppl.ast.Parenthesis;
import ppl.ast.Select;
import ppl.ast.Statement;
import ppl.ast.Return;
import ppl.ast.TypeExpr;
import ppl.ast.Unary;
import ppl.ast.ValueOf;
import ppl.ast.Variable;

import ppl.build.BuildState;
import ppl.build.ReferenceInformation;

import ppl.check.CheckModule;
import ppl.check.EscapeAnalysis;
import ppl.check.ControlFlow;

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

import ppl.opt.opt_dead_code;

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

import ppl.resolve.AfterResolution;
import ppl.resolve.ResolveCalloc;
import ppl.resolve.FunctionFinder;
import ppl.resolve.ImportFinder;
import ppl.resolve.TypeFinder;
import ppl.resolve.OverloadCollector;
import ppl.resolve.ResolveAs;
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
