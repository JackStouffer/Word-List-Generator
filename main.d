/+ dub.sdl:
    name "wordlist_gen"
    dependency "dateparser" version="~>3.0.0"
+/

import std.stdio;
import std.datetime;
import std.typecons;
import std.range.primitives;

enum InfoType
{
    Common,
    Person,
    Pet,
    Date
}

struct Info
{
    InfoType type;
    string data;
    Nullable!Date date;

    this(InfoType t, string d, Date d2)
    {
        type = t;
        data = d;
        date = d2;
    }

    this(InfoType t, string d)
    {
        type = t;
        data = d;
    }
}

Info[] infoArray;


/**
 * Manages all of the separate guess generating functions and calls them
 * from the data in infoArray
 */
void genWordList()
{
    import std.algorithm.iteration : map, filter, joiner;
    import std.algorithm.mutation : copy;
    import std.array : appender, array;
    import std.conv : to;
    import std.string : toLower, capitalize, toUpper;

    writeln("Generating list of password guesses");

    auto app = appender!(string[])();
    app.reserve(infoArray.length * 40_100);

    // take all people and pet names,  their
    // upper, lower, leet, and capitalized versions
    // and get all combinations of them
    auto personCombinations = infoArray
        .filter!(a => a.type == InfoType.Person)
        .map!(a => [a.data.capitalize, a.data.toLower, a.data.toUpper, a.data.toLeet])
        .joiner
        .array
        .combinations;
    app.put(personCombinations);

    auto petCombinations = infoArray
        .filter!(a => a.type == InfoType.Pet)
        .map!(a => [a.data.capitalize, a.data.toLower, a.data.toUpper, a.data.toLeet])
        .joiner
        .array
        .combinations;
    app.put(petCombinations);

    //Get standard guesses from dates and strings
    foreach (item; infoArray.filter!(a => a.type != InfoType.Date))
        commonGuesses(item, app);

    foreach (item; infoArray.filter!(a => a.type == InfoType.Date))
        guessesFromDate(item, app);

    auto f = File("wordlist_" ~ to!string(cast(TimeOfDay) Clock.currTime()) ~ ".txt", "w");
    writeln("Writing ", app.data.length, " guesses to file ", f.name);

    app.data.map!(a => a ~ "\n").copy(f.lockingTextWriter());
}


/**
 * Takes an Info with string data and generates common password
 * patterns from the string.
 *
 * Params:
 *     info = the Info to gen guesses from
 *     ouput = an Output range for strings to put the guesses
 */
void commonGuesses(Output)(Info info, ref Output output) if (isOutputRange!(Output, string))
{
    import std.algorithm.searching : canFind;
    import std.conv : to;
    import std.string : toLower, capitalize, toUpper;

    // some people leave spaces in their passwords
    // most don't
    if (info.data.canFind(' '))
    {
        auto temp = info;
        temp.data = temp.data.replace(" ", "");
        commonGuesses(temp, output);
    }

    auto lower = info.data.toLower;
    auto capitalized = info.data.capitalize;
    auto upper = info.data.toUpper;
    auto leet = info.data.toLeet;
    // optimize for rare case where there are no "1337" characters in
    // the item
    bool useLeet = leet != lower && leet != capitalized && leet != upper;

    // The most simple, this would probably get detected with most wordlists
    output.put(lower);
    output.put(capitalized);
    output.put(upper);
    if (useLeet)
        output.put(leet);

    // for some reason surrounding something with either 1's or !'s
    // is a very common pattern
    output.put("1" ~ lower ~ "1");
    output.put("1" ~ capitalized ~ "1");
    output.put("1" ~ upper ~ "1");
    output.put("!" ~ lower ~ "!");
    output.put("!" ~ capitalized ~ "!");
    output.put("!" ~ upper ~ "!");

    if (useLeet)
    {
        output.put("1" ~ leet ~ "1");
        output.put("!" ~ leet ~ "!");
    }

    // Using numbers at the end in order to satisfy either a length
    // or number requirement is also very common
    // Also covers people who put a year at the end of something
    foreach (i; 0 .. 10_000)
    {
        auto s = to!string(i);
        output.put(lower ~ s);
        output.put(capitalized ~ s);
        output.put(upper ~ s);
        if (useLeet)
            output.put(leet ~ s);
    }
    // other very common patterns
    foreach (s; ["12345", "123456", "1234567", "12345678", "123456789", "1234567890",
        "00", "000", "0000", "00000", "000000", "0000000", "00000000", "000000000", "0000000000",
        "asdf", "qwerty", "zxcvbnm", "asdfghjkl", "ABC", "ASDF", "ZXCVBNM", "QWERTY"])
    {
        output.put(lower ~ s);
        output.put(capitalized ~ s);
        output.put(upper ~ s);
        if (useLeet)    
            output.put(leet ~ s);
    }

    if (info.type == InfoType.Person)
        guessesFromDate(info, output);
}


/**
 * Take an Info with date info and generate guesses from common date
 * formats
 *
 * Params:
 *     info = the Info to gen guesses from
 *     ouput = an Output range for strings to put the guesses
 */
void guessesFromDate(Output)(Info info, ref Output output) if (isOutputRange!(Output, string))
{
    import std.conv : to;

    auto year = to!string(info.date.year);
    auto month = to!string(cast(int) info.date.month);
    auto day = to!string(info.date.day);

    output.put(year ~ month ~ day);
    output.put(year[2 .. $] ~ month ~ day);
    output.put(year ~ month);
    output.put(year[2 .. $] ~ month);
    output.put(month ~ year);
    output.put(month ~ year[2 .. $]);
    output.put(month ~ day);
    output.put(month ~ day ~ year);
    output.put(month ~ day ~ year[2 .. $]);
    output.put(day ~ month ~ year);
    output.put(day ~ month ~ year[2 .. $]);
    output.put(day ~ month);

    foreach (sep; [",", ".", "/", "-", "_"])
    {
        output.put(year ~ sep ~ month ~ sep ~ day);
        output.put(year[2 .. $] ~ sep ~ month ~ sep ~ day);
        output.put(year ~ sep ~ month);
        output.put(year[2 .. $] ~ sep ~ month);
        output.put(month ~ sep ~ year);
        output.put(month ~ sep ~ year[2 .. $]);
        output.put(month ~ sep ~ day);
        output.put(day ~ sep ~ month ~ sep ~ year);
        output.put(month ~ sep ~ day ~ sep ~ year);
        output.put(day ~ sep ~ month);
    }
}

/**
 * Takes an array of strings and returns an array of strings of all
 * combinations of the inputs. O(n^2)
 */
auto combinations(string[] input)
{
    import std.math : pow;

    string[] combinations;
    immutable powLen = pow(2, input.length);

    foreach (i; 0 .. powLen)
    {
        string temp = "";

        foreach (j; 0 .. input.length)
        {
            if (i & pow(2, j))
                temp ~= input[j];
        }

        if (temp != "")
            combinations ~= temp;
    }

    return combinations;
}


/**
 * Takes a string and replaces the e's with 3's, the t's with 7's, and the
 * l's with 1's.
 *
 * Params:
 *     input = the string to transform
 * Returns:
 *     a newly allocated string
 */
auto toLeet(string input)
{
    import std.string : replace, toLower;

    return input.toLower
        .replace("e", "3")
        .replace("t", "7")
        .replace("l", "1");
}

void getData()
{
    import std.string : chomp;
    import dateparser : parse;

    string input;

    outer: while (true)
    {
        write("\nType: ");
        input = readln.chomp;

        switch (input)
        {
            case "person":
            case "p":
                write("First Name: ");
                auto name = readln.chomp;
                write("Date of birth: ");
                Date date;

                try
                {
                    date = cast(Date) readln.chomp.parse;
                }
                catch (Exception)
                {
                    writeln("Not a valid date");
                    break;
                }

                infoArray ~= Info(InfoType.Person, name, date);
                break;

            case "pet":
            case "z":
                write("Name of Pet: ");
                auto pet = readln.chomp;
                infoArray ~= Info(InfoType.Pet, pet);
                break;

            case "date":
            case "d":
                write("Date: ");
                Date idate;

                try
                {
                    idate = cast(Date) readln.chomp.parse;
                }
                catch (Exception)
                {
                    writeln("Not a valid date");
                    break;
                }

                infoArray ~= Info(InfoType.Date, "", idate);
                break;

            case "common":
            case "c":
                write("Data: ");
                auto data = readln.chomp;
                infoArray ~= Info(InfoType.Common, data);
                break;

            case "finish":
            case "f":
                genWordList();
                break outer;

            case "quit":
            case "q":
                break outer;

            default:
                writeln("Not a valid info type");
                break;
        }
    }
}


void main()
{
    writeln(q{
                            [Targeted Word List Generator]

        FOR EDUCATIONAL PURPOSES ONLY. THE AUTHOR DOES NOT CONDONE NOR ENDORSE
        UNAUTHORIZED ACCESS OF COMPUTER SYSTEMS. Licensed under the MIT License.

        Generates a password list using information about the owner of the
        device you are attempting to access.

        It is very common for people to create passwords using items from
        their daily lives. So this program takes that info and generates
        common password formats from it. Good examples of information to
        include are things like

        * the owner and their date of birth
        * phone numbers
        * address number
        * all of the owners family members and their dates of birth
        * important dates, like an anniversary
        * names of the owners pets
        * places where the person has lived
        * names of the companies this person has worked for
        * make or model of cars the person has owned
        * favorite bands

        Generated files are roughly of size n*40000, where n is the amount
        of info added.

        Commands:
            common | c  =  a string that represents something important to this person
            person | p  =  a person, will ask for name and DoB
            pet | z     =  a pet
            date | d    =  an important date
            finish | f  =  finish and generate
            quit | q    =  quit without generating
    });

    getData();
}