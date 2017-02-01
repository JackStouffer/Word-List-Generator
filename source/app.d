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
void commonGuesses(Output)(Info info, ref Output output) if (isOutputRange!(Output, string))
{
    import std.algorithm.searching : canFind;
    import std.conv : to, toChars;
    import std.string : replace, toLower, capitalize, toUpper;
    import std.range : chain;

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
    // optimize for the case where there are no "1337" characters in
    // the item
    bool useLeet = leet != lower && leet != capitalized && leet != upper;

    // The most simple, this would probably get detected with most wordlists
    output.put(chain(lower, "\n"));
    output.put(chain(capitalized, "\n"));
    output.put(chain(upper, "\n"));
    if (useLeet)
        output.put(chain(leet, "\n"));

    // for some reason surrounding something with either 1's or !'s
    // is a very common pattern
    output.put(chain("1", lower, "1", "\n"));
    output.put(chain("1", capitalized, "1", "\n"));
    output.put(chain("1", upper, "1", "\n"));
    output.put(chain("!", lower, "!", "\n"));
    output.put(chain("!", capitalized, "!", "\n"));
    output.put(chain("!", upper, "!", "\n"));

    if (useLeet)
    {
        output.put(chain("1", leet, "1", "\n"));
        output.put(chain("!", leet, "!", "\n"));
    }

    // Using numbers at the end in order to satisfy either a length
    // or number requirement is also very common
    // Also covers people who put a year at the end of something
    foreach (i; 0 .. 10_000)
    {
        auto s = i.toChars;
        output.put(chain(lower, s, "\n"));
        output.put(chain(capitalized, s, "\n"));
        output.put(chain(upper, s, "\n"));
        if (useLeet)
            output.put(chain(leet, s, "\n"));
    }

    // other very common patterns
    foreach (s; commonPatterns)
    {
        output.put(chain(lower, s, "\n"));
        output.put(chain(capitalized, s, "\n"));
        output.put(chain(upper, s, "\n"));
        if (useLeet)
            output.put(chain(leet, s, "\n"));
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
    import std.conv : to, toChars;
    import std.range : chain;

    auto year = toChars(cast(int) info.date.year);
    auto month = toChars(cast(int) info.date.month);
    auto day = toChars(cast(int) info.date.day);

    output.put(chain(year, month, day, "\n"));
    output.put(chain(year[2 .. year.length], month, day, "\n"));
    output.put(chain(year, month, "\n"));
    output.put(chain(year[2 .. year.length], month, "\n"));
    output.put(chain(month, year, "\n"));
    output.put(chain(month, year[2 .. year.length], "\n"));
    output.put(chain(month, day, "\n"));
    output.put(chain(month, day, year, "\n"));
    output.put(chain(month, day, year[2 .. year.length], "\n"));
    output.put(chain(day, month, year, "\n"));
    output.put(chain(day, month, year[2 .. year.length], "\n"));
    output.put(chain(day, month, "\n"));

    foreach (sep; seperators)
    {
        output.put(chain(year, sep, month, sep, day, "\n"));
        output.put(chain(year[2 .. year.length], sep, month, sep, day, "\n"));
        output.put(chain(year, sep, month, "\n"));
        output.put(chain(year[2 .. year.length], sep, month, "\n"));
        output.put(chain(month, sep, year, "\n"));
        output.put(chain(month, sep, year[2 .. year.length], "\n"));
        output.put(chain(month, sep, day, "\n"));
        output.put(chain(month, sep, day, sep, year, "\n"));
        output.put(chain(month, sep, day, sep, year[2 .. year.length], "\n"));
        output.put(chain(day, sep, month, sep, year, "\n"));
        output.put(chain(day, sep, month, sep, year[2 .. year.length], "\n"));
        output.put(chain(day, sep, month, "\n"));
    }
}

/**
 * Takes an array of strings and returns an array of strings of all
 * combinations of the inputs. O(n^2)
 */
void combinations(Output)(string[] input, ref Output output) if (isOutputRange!(Output, string))
{
    import std.math : pow;
    import std.range : chain;

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
            output.put(chain(temp, "\n"));
    }
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
auto toLeet(Range)(Range input) if (
    isInputRange!Range && is(Unqual!(ElementEncodingType!Range) == char))
{
    import std.algorithm.iteration : map;
    import std.array : array;
    import std.ascii : toLower;
    import std.utf : byChar;

    return input.byChar.map!((a) {
        auto c = a.toLower;
        switch (c)
        {
            case 'e':
                return '3';
            case 't':
                return '7';
            case 'l':
                return '1';
            default:
                return c;
        }
    }).array;
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
        * names of the owners past/current pets
        * places where the person has lived
        * names of the companies this person has worked for
        * make or model of cars the person has owned
        * favorite bands

        Generated files are roughly of length in lines of n*40000, where n is
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