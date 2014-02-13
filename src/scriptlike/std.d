/++
Scriptlike: Utility to aid in script-like programs.
Written in the D programming language.

Automatically pulls in anything from Phobos likely to be useful for scripts.

std.file and std.path are deliberately omitted here because they are wrapped
by scriptlike.path.

curl is omitted here because it involves an extra link dependency.
+/

module scriptlike.std;

public import std.algorithm;
public import std.array;
public import std.bigint;
public import std.conv;
public import std.datetime;
public import std.exception;
public import std.getopt;
public import std.math;
public import std.process;
public import std.random;
public import std.range;
public import std.regex;
public import std.stdio;
public import std.string;
public import std.system;
public import std.traits;
public import std.typecons;
public import std.typetuple;
public import std.uni;
public import std.variant;