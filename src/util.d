module flatman.util;

import std.algorithm;


T[] without(T)(T[] array, T elem){
	auto i = array.countUntil(elem);
	return array[0..i] ~ array[i+1..$];
}