/++
This program runs and tests one or all of the "features" examples
in this directory.
+/
import scriptlike;

void function()[string] lookupTest; // Lookup test by name
string testName; // Name of test being run

void main(string[] args)
{
	// Init test lookup
	lookupTest = [
		"All":                       &testAll,

		"features/AutomaticPhobosImport":     &testAutomaticPhobosImport,
		"features/CommandEchoing":            &testCommandEchoing,
		"features/DisambiguatingWrite":       &testDisambiguatingWrite,
		"features/DryRunAssistance":          &testDryRunAssistance,
		"features/Fail":                      &testFail,
		"features/Filepaths":                 &testFilepaths,
		"features/ScriptStyleShellCommands":  &testScriptStyleShellCommands,
		"features/StringInterpolation":       &testStringInterpolation,
		"features/TryAsFilesystemOperations": &testTryAsFilesystemOperations,
		"features/UserInputPrompts":          &testUserInputPrompts,

		"DubProject":                &testDubProject,
		"SingleFile":                &testSingleFile,
	];

	// Check args
	getopt(args, "v", &scriptlikeEcho);

	failEnforce(
		args.length == 2,
		"Invalid args.\n",
		"\n",
		"Usage: testExample [-v] NAME\n",
		"\n",
		"Options:\n",
		"-v  Verbose\n",
		"\n",
		"Examples:\n",
		"    testExample All\n",
		"    testExample features/UserInputPrompts\n",
		"\n",
		"Available Test Names:\n",
		"    ", lookupTest.keys.sort().join("\n    "),
	);

	testName = args[1];
	failEnforce(
		(testName in lookupTest) != null,
		"No such test '", testName, "'.\n",
		"Available Test Names:\n",
		"    ", lookupTest.keys.sort().join("\n    "),
	);

	// Setup for test
	chdir(thisExePath.dirName);
	tryMkdirRecurse("bin/features"); // gdmd doesn't automatically create the output directory.

	// Run test
	writeln("Testing ", testName); stdout.flush();
	lookupTest[testName]();
}

alias RunResult = Tuple!(int, "status", string, "output");

/++
Compiles and runs a test, returning the test's output.

Always displays, but does not return, the compiler output.

Throws upon failure.
+/
string compileAndRun(string testName, string runCmdSuffix=null)
{
	return _compileAndRunImpl(true, testName, runCmdSuffix).output;
}

/++
Compiles and runs a test, returning the status code and the test's output.

Always displays, but does not return, the compiler output.
+/
RunResult tryCompileAndRun(string testName, string runCmdSuffix=null)
{
	return _compileAndRunImpl(false, testName, runCmdSuffix);
}

/++
Separating the compile & build steps is important here because on
AppVeyor/Windows the linker outputs a non-fatal message:
    "[...] not found or not built by the last incremental link; performing full link)"

Any such non-fatal compilation messages MUST NOT be included in this
function's return value or they will cause the tests to fail.
+/
RunResult _compileAndRunImpl(bool throwOnError, string testName, string runCmdSuffix)
{
	version(Windows) auto exeSuffix = ".exe";
	else             auto exeSuffix = "";

	auto compileCmd = compilerCommand(testName);
	auto runBinary = fixSlashes("bin/"~testName~exeSuffix);
	auto runCmd = runBinary~runCmdSuffix;

writeln("compileCmd: ", compileCmd); stdout.flush();
writeln("runCmd: ", runCmd); stdout.flush();

	if(throwOnError)
	{
		run(compileCmd);
		auto output = runCollect(runCmd);
		return RunResult(0, output);
	}
	else
	{
		auto status = tryRun(compileCmd);
		if(status != 0)
			return RunResult(status, null);

		return tryRunCollect(runCmd);
	}
}

string compilerCommand(string testName)
{
	string archFlag = "";
	auto envArch = environment.get("Darch", "");
	if(envArch == "x86_64") archFlag = "-m64";
	if(envArch == "x86")    archFlag = "-m32";

	auto libSourceFiles = cast(string)
		dirEntries("../src", "*.d", SpanMode.breadth).
		map!(a => cast(const(ubyte)[]) escapeShellArg(a)).
		joiner(cast(const(ubyte)[]) " ").
		array;

	version(Windows) auto execName = testName~".exe";
	else             auto execName = testName;

	auto envDmd = environment.get("DMD", "dmd");
	return envDmd~" "~archFlag~" -debug -g -I../src "~libSourceFiles~" -ofbin/"~execName~" ../examples/"~testName~".d";
}

string normalizeNewlines(string str)
{
	version(Windows) return str.replace("\r\n", "\n");
	else             return str;
}

string fixSlashes(string path)
{
	version(Windows)    return path.replace(`/`, `\`);
	else version(Posix) return path.replace(`\`, `/`);
	else static assert(0);
}

string quote(string str)
{
	version(Windows)    return `"` ~ str ~ `"`;
	else version(Posix) return `'` ~ str ~ `'`;
	else static assert(0);
}

void testAll()
{
	bool failed = false; // Have any tests failed?
	
	foreach(name; lookupTest.keys.sort())
	if(lookupTest[name] != &testAll)
	{
		// Instead of running the test function directly, run it as a separate
		// process. This way, we can safely continue running all the tests
		// even if one throws an AssertError or other Error.
		auto verbose = scriptlikeEcho? "-v " : "";
		auto status = tryRun("." ~ dirSeparator ~ "testExample " ~ verbose ~ name);
		if(status != 0)
			failed = true;
	}
	writeln("Done running tests for examples."); stdout.flush();

	failEnforce(!failed, "Not all tests succeeded.");
}

void testAutomaticPhobosImport()
{
	auto output = compileAndRun(testName).normalizeNewlines;
	assert(output == "Works!\n");
}

void testCommandEchoing()
{
	immutable expected = 
"run: echo Hello > file.txt
mkdirRecurse: "~("some/new/dir".fixSlashes)~"
copy: file.txt -> "~("some/new/dir/target name.txt".fixSlashes.quote)~"
Gonna run foo() now...
foo: i = 42
";
	
	auto output = compileAndRun(testName).normalizeNewlines;
	assert(output == expected);
}

void testDisambiguatingWrite()
{
	immutable expected =  "Hello worldHello world";

	auto output = compileAndRun(testName).normalizeNewlines;
	assert(output == expected);
}

void testDryRunAssistance()
{
	immutable expected =
"copy: original.d -> app.d
run: dmd app.d -ofbin/app
exists: another-file
";

	auto output = compileAndRun(testName).normalizeNewlines;
	assert(output == expected);
}

void testFail()
{
	auto result = tryCompileAndRun(testName);
	assert(result.status > 0);
	assert(result.output.normalizeNewlines.strip == "Fail: ERROR: Need two args, not 0!");

	result = tryCompileAndRun(testName, " abc 123");
	assert(result.status > 0);
	assert(result.output.normalizeNewlines.strip == "Fail: ERROR: First arg must be 'foobar', not 'abc'!");

	auto output = compileAndRun(testName,  " foobar 123");
	assert(output == "");
}

void testFilepaths()
{
	immutable expected = 
		("foo/bar/different subdir/Filename with spaces.txt".fixSlashes.quote) ~ "\n" ~
		("foo/bar/different subdir/Filename with spaces.txt".fixSlashes) ~ "\n";

	auto output = compileAndRun(testName).normalizeNewlines;
	assert(output == expected);
}

void testScriptStyleShellCommands()
{
	// This test relies on "dmd" being available on the PATH
	auto dmdResult = tryRunCollect("dmd --help");
	if(dmdResult.status != 0)
	{
		writeln(`Skipping `, testName, `: Couldn't find 'dmd' on the PATH.`); stdout.flush();
		return;
	}

	immutable inFile = "testinput.txt";
	scope(exit)
		tryRemove(inFile);

	writeFile(inFile, "\n");

	version(OSX) enum key = "Return";
	else         enum key = "Enter";

	immutable expectedExcerpt =
		"Press "~key~" to continue...Error: unrecognized switch '--bad-flag'\n";

	auto output = compileAndRun(testName, " < " ~ inFile).normalizeNewlines;
	assert(output.canFind(expectedExcerpt));
}

void testStringInterpolation()
{
	immutable expected = 
"The number 21 doubled is 42!
Empty braces output nothing.
Multiple params: John Doe.
";

	auto output = compileAndRun(testName).normalizeNewlines;
	assert(output == expected);
}

void testTryAsFilesystemOperations()
{
	auto output = compileAndRun(testName).normalizeNewlines;
	assert(output == "");
}

void testUserInputPrompts()
{
	immutable inFile = "testinput.txt";
	scope(exit)
		tryRemove(inFile);

	writeFile(inFile,
"Nana
20
y
testExample.d
2
7
\n\n"
	);

	version(OSX) enum key = "Return";
	else         enum key = "Enter";

	immutable expectedExcerpt =
"Please enter your name
> And your age
> Do you want to continue?
> Where you do want to place the output?
> What color would you like to use?
       1. Blue
       2. Green
No Input. Quit

> Enter a number from 1 to 10
> Press "~key~" to continue...Hit Enter again, dood!!";

	auto output = compileAndRun(testName, " < " ~ inFile).normalizeNewlines;
	assert(output.canFind(expectedExcerpt));
}

void testUseInScripts(string subdir, Path workingDir, string command, bool checkReportedDir=true)
{
	auto projDir = Path("../examples/"~subdir);

	// Test with cmdline arg
	{
		string expected;
		if(checkReportedDir)
		{
			expected = text(
"This script is in directory: ", (thisExePath.dirName ~ projDir), "
Hello, Frank!
");
		}
		else
		{
			expected = text(
"Hello, Frank!
");
		}
		auto output = workingDir.runCollect( command~" Frank" ).normalizeNewlines;
		if(output != expected)
		{
			writeln("expected:========================");
			writeln(expected);
			writeln("output:========================");
			writeln(output);
			writeln("========================");
			stdout.flush();
		}
		assert(output.endsWith(expected));
	}

	// Test interactive
	{
		immutable inFile = "testinput.txt";
		scope(exit)
			tryRemove(workingDir ~ inFile);

		writeFile(workingDir ~ inFile, "George\n");

		string expected;
		if(checkReportedDir)
		{
			expected = text(
"This script is in directory: ", (thisExePath.dirName ~ projDir), "
What's your name?
> Hello, George!
");
		}
		else
		{
			expected = text(
"What's your name?
> Hello, George!
");
		}

		auto output = workingDir.runCollect( command~" < "~inFile ).normalizeNewlines;
		if(output != expected)
		{
			writeln("expected:========================");
			writeln(expected);
			writeln("output:========================");
			writeln(output);
			writeln("========================");
			stdout.flush();
		}
		assert(output.endsWith(expected));
	}
}

string getDubEnvArgs()
{
	string args;
	
	if(environment.get("Darch") !is null)
		args ~= " --arch=" ~ environment["Darch"];

	if(environment.get("DC") !is null)
		args ~= " --compiler=" ~ environment["DC"];

	return args;
}

void testDubProject()
{
	// Force rebuild
	tryRemove("../examples/dub-project/myscript");
	tryRemove("../examples/dub-project/myscript.exe");

	// Do test
	testUseInScripts("dub-project", Path("../examples/dub-project"), "dub --vquiet "~getDubEnvArgs~" -- ");
}

void testSingleFile()
{
	// Do tests
	writeln("    Testing from its own directory..."); stdout.flush();
	testUseInScripts("single-file", Path("../examples/single-file"), "dub --vquiet --single "~getDubEnvArgs~" myscript.d -- ", false);

	writeln("    Testing from different directory..."); stdout.flush();
	testUseInScripts(
		"single-file",
		Path("../tests/bin"),
		"dub --vquiet --single "~getDubEnvArgs~" "~Path("../../examples/single-file/myscript.d").raw~" -- ",
		false
	);
}
