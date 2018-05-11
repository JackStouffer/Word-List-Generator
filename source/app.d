import std.datetime;
import std.range.primitives;
import std.stdio;
import std.traits;
import std.typecons;

enum InfoType
{
    Address,
    Common,
    Date,
    Person,
    Pet,
    Phone,
}


struct Info
{
    InfoType type;
    string data;
    Nullable!Date date;

    this(InfoType t, string d, Date d2) @safe pure
    {
        type = t;
        data = d;
        date = d2;
    }

    this(InfoType t, string d) @safe pure
    {
        type = t;
        data = d;
    }
}


Info[] infoArray;
static immutable commonPatterns = [
    "12345", "123456", "1234567", "12345678", "123456789", "1234567890",
    "00", "000", "0000", "00000", "000000", "0000000", "00000000", "000000000",
    "0000000000", "11111111", "987654321", "1QAZ2WSX", "1Qaz2Wsx", "1qaz2wsx",
    "AAAAAA", "ABC", "ABCD1234", "ASDF", "ASDFASDF", "ASDFGHJKL", "Aaaaaa",
    "Abc", "Abcd1234", "Asdf", "Asdfasdf", "Asdfghjkl", "PASSWORD", "Password",
    "Q1W2E3R4", "QAZWSX", "QWERT", "QWERTY", "QWERTYUIOP", "Qazwsx", "Qwert",
    "Qwerty", "Qwertyuiop", "ZXCVBNM", "Zxcvbnm", "aaaaaa", "abc", "abcd1234",
    "asdf", "asdfasdf", "asdfghjkl", "password", "q1w2e3r4", "qazwsx", "qwert",
    "qwerty", "qwertyuiop", "zxcvbnm"
];
static immutable seperators = [",", ".", "/", "-", "_"];


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
    import std.range : chain;

    writeln("Generating list of password guesses");
    auto f = File("wordlist_" ~ to!string(cast(TimeOfDay) Clock.currTime()) ~ ".txt", "w");

    auto app = f.lockingTextWriter();

    // take all people and pet names, their
    // lower and capitalized versions
    // and get all combinations of them
    infoArray
        .filter!(a => a.type == InfoType.Person || a.type == InfoType.Pet)
        .map!(a => [a.data.capitalize, a.data.toLower])
        .joiner
        .array
        .combinations(app);

    // Do the same for addresses and phone numbers
    infoArray
        .filter!(a => a.type == InfoType.Address || a.type == InfoType.Phone)
        .map!(a => a.data)
        .array
        .combinations(app);

    //Get standard guesses from dates and strings
    foreach (item; infoArray.filter!(a => a.type != InfoType.Date
                                     && a.type != InfoType.Phone
                                     && a.type != InfoType.Address))
        commonGuesses(item, app);

    foreach (item; infoArray.filter!(a => a.type == InfoType.Date))
        guessesFromDate(item, app);

    writeln("Wrote ", f.size, " bytes to file ", f.name);
}


/**
 * Takes an Info with string data and generates common password
 * patterns from the string.
 *
 * Params:
 *     info = the Info to gen guesses from
 *     ouput = an Output range for strings to put the guesses
 */
void commonGuesses(Output)(Info info, ref Output output)
if (isOutputRange!(Output, string))
{
    import std.algorithm.comparison : equal;
    import std.algorithm.searching : canFind;
    import std.conv : to, toChars;
    import std.string : replace, toLower, capitalize, toUpper;
    import std.range : chain;
    import std.utf : byCodeUnit;

    // some people leave spaces in their passwords
    // most don't
    if (info.data.canFind(' '))
    {
        auto temp = info;
        temp.data = temp.data.replace(" ", "");
        commonGuesses(temp, output);
    }

    auto lower = info.data.toLower.byCodeUnit;
    auto capitalized = info.data.capitalize.byCodeUnit;
    auto upper = info.data.toUpper.byCodeUnit;
    auto leet = info.data.toLeet.byCodeUnit;
    auto one = "1".byCodeUnit;
    auto point = "!".byCodeUnit;
    auto newLine = "\n".byCodeUnit;
    // optimize for the case where there are no "1337" characters in
    // the item
    immutable useLeet = !leet.equal(lower) && !leet.equal(capitalized) && !leet.equal(upper);

    // The most simple, this would probably get detected with most wordlists
    output.put(chain(
        lower, newLine,
        capitalized, newLine,
        upper, newLine
    ));
    if (useLeet)
        output.put(chain(leet, newLine));

    // for some reason surrounding something with either 1's or !'s
    // is a very common pattern
    output.put(chain(
        one, lower, one, newLine,
        one, capitalized, one, newLine,
        one, upper, one, newLine,
        point, lower, point, newLine,
        point, capitalized, point, newLine,
        point, upper, point, newLine
    ));

    if (useLeet)
    {
        output.put(chain(
            one, leet, one, newLine,
            point, leet, point, newLine
        ));
    }

    // Using numbers at the end in order to satisfy either a length
    // or number requirement is also very common
    // Also covers people who put a year at the end of something
    foreach (i; 0 .. 3_000)
    {
        auto s = i.toChars;
        output.put(chain(
            lower.byCodeUnit, s, newLine,
            capitalized.byCodeUnit, s, newLine,
            upper.byCodeUnit, s, newLine
        ));
        if (useLeet)
            output.put(chain(leet.byCodeUnit, s, newLine));
    }

    // other very common patterns
    foreach (s; commonPatterns)
    {
        output.put(chain(
            lower.byCodeUnit, s.byCodeUnit, newLine,
            capitalized.byCodeUnit, s.byCodeUnit, newLine,
            upper.byCodeUnit, s.byCodeUnit, newLine
        ));
        if (useLeet)
            output.put(chain(leet.byCodeUnit, s.byCodeUnit, newLine));
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
void guessesFromDate(Output)(Info info, ref Output output)
if (isOutputRange!(Output, string))
{
    import std.conv : to, toChars;
    import std.range : chain;
    import std.utf : byCodeUnit;

    auto year = toChars(cast(int) info.date.year);
    auto month = toChars(cast(int) info.date.month);
    auto day = toChars(cast(int) info.date.day);
    auto newLine = "\n".byCodeUnit;

    if (info.type == InfoType.Person)
    {
        output.put(chain(
            info.data.byCodeUnit, year, month, day, newLine,
            info.data.byCodeUnit, day, month, year, newLine,
            info.data.byCodeUnit, day, month, year[2 .. year.length], newLine,
            info.data.byCodeUnit, month, year, newLine,
            info.data.byCodeUnit, month, year[2 .. year.length], newLine
        ));
    }

    output.put(chain(
        year, newLine,
        year, month, day, newLine,
        year[2 .. year.length], month, day, newLine,
        year, month, newLine,
        year[2 .. year.length], month, newLine,
        month, year, newLine,
        month, year[2 .. year.length], newLine,
        month, day, newLine,
        month, day, year, newLine,
        month, day, year[2 .. year.length], newLine,
        day, month, year, newLine,
        day, month, year[2 .. year.length], newLine,
        day, month, newLine
    ));

    foreach (s; seperators)
    {
        auto sep = s.byCodeUnit;
        output.put(chain(
            year, sep, month, sep, day, newLine,
            year[2 .. year.length], sep, month, sep, day, newLine,
            year, sep, month, newLine,
            year[2 .. year.length], sep, month, newLine,
            month, sep, year, newLine,
            month, sep, year[2 .. year.length], newLine,
            month, sep, day, newLine,
            month, sep, day, sep, year, newLine,
            month, sep, day, sep, year[2 .. year.length], newLine,
            day, sep, month, sep, year, newLine,
            day, sep, month, sep, year[2 .. year.length], newLine,
            day, sep, month, newLine
        ));
    }
}

@safe unittest
{
    import std.array : appender;
    import std.algorithm.searching : canFind;
    import std.stdio;

    auto app = appender!(char[])();

    auto expected = [
        "2018", "2018-1-1", "201811", "112018", "2018.1.1",
        "2018/1/1", "1/1/2018", "1.1.2018", "1118"
    ];
    Info i = Info(InfoType.Date, "", Date(2018, 1, 1));
    guessesFromDate(i, app);
    auto data = app.data;
    foreach (e; expected)
        assert(data.canFind(e));
}

/**
 * Takes an array of strings and returns an array of strings of all
 * combinations of the inputs. O(n^2)
 */
void combinations(Output)(string[] input, ref Output output)
if (isOutputRange!(Output, string))
{
    import std.math : pow;
    import std.range : chain;

    immutable powLen = pow(2, input.length);

    foreach (i; 0 .. powLen)
    {
        string temp = "";

        foreach (j; 0 .. input.length)
            if (i & pow(2, j))
                temp ~= input[j];

        if (temp != "")
            output.put(chain(temp, "\n"));
    }
}

@safe unittest
{
    import std.array : appender;
    import std.algorithm.searching : canFind;

    auto app = appender!(char[])();

    ["Test", "Hello", "World"].combinations(app);
    auto expected = [
        "Test", "Hello", "World", "TestHello", "TestWorld",
        "TestHelloWorld", "HelloWorld"
    ];
    auto data = app.data;
    foreach (e; expected)
        assert(data.canFind(e));
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
auto toLeet(Range)(Range input)
if (isInputRange!Range && is(Unqual!(ElementEncodingType!Range) == char))
{
    import std.algorithm.iteration : map;
    import std.array : array;
    import std.ascii : toLower;
    import std.utf : byChar;

    return input.byChar.map!((a) {
        immutable c = a.toLower;
        switch (c)
        {
            case 'e':
                return '3';
            case 't':
                return '7';
            case 'l':
                return '1';
            case 'o':
                return '0';
            default:
                return c;
        }
    }).array;
}


@safe pure unittest
{
    assert("ford".toLeet == "f0rd");
    assert("test".toLeet == "73s7");
    assert("leet".toLeet == "1337");
}


void getData()
{
    import std.conv : to;
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

            case "phone":
            case "e":
                write("Phone Number: ");
                auto phone = readln.chomp;

                try
                {
                    cast(void) to!size_t(phone);
                }
                catch (Exception)
                {
                    writeln("Not a valid phone number. Please only use numbers");
                    break;
                }

                infoArray ~= Info(InfoType.Phone, phone);
                break;

            case "address":
            case "w":
                write("Address Number: ");
                auto address = readln.chomp;

                try
                {
                    cast(void) to!size_t(address);
                }
                catch (Exception)
                {
                    writeln("Not a valid address number. Please only use numbers");
                    break;
                }

                infoArray ~= Info(InfoType.Address, address);
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

version(unittest)
{
    void main() {}
}
else
{
    void main()
    {
        import core.memory : GC;

        // Almost no garbage, no need to collect for short running
        // program
        GC.disable();

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
            * names of the owners past/current pets
            * places where the person has lived
            * names of the companies this person has worked for
            * make or model of cars the person has owned
            * favorite bands

            Generated files are roughly of length in lines of n*12000, where n is
            the amount of info added.

            Commands:
                common | c   =  a string that represents something important to this person
                person | p   =  a person, will ask for name and DoB
                pet | z      =  a pet
                date | d     =  an important date
                phone | e    =  a phone number
                address | w  =  an address number or zip code
                finish | f   =  finish and generate
                quit | q     =  quit without generating
        });

        getData();
    }
}