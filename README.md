FOR EDUCATIONAL PURPOSES ONLY. THE AUTHOR DOES NOT CONDONE NOR ENDORSE
UNAUTHORIZED ACCESS OF COMPUTER SYSTEMS. Licensed under the MIT License.

Generates a password list using information about the owner of the
device you are attempting to access. It is very common for people to
create passwords using items from their daily lives. So this program
takes that info and generates common password formats from it. Good
examples of information to give to the program are things like

* the owner and their date of birth
* phone numbers
* address number
* all of the owner's family members and their dates of birth
* important dates, like an anniversary
* names of the owner's past/current pets
* places where the person has lived
* names of the companies this person has worked for
* make or model of cars the person has owned
* favorite bands
* the name of the service the password is being used for, e.g. the
name of the OS or the name of the website

Using leaked password databases as a sample, roughly 30% of people will use a
password which this program will catch. According to other research, another
10% of people use passwords in the 500 top worst password list. So using this
program in conjunction with other wordlists can yield almost half of all accounts.

## Install

First, [install dub](https://code.dlang.org/download).

Next,

```
$ dub fetch wordlist_gen
```

## Use

```
$ dub run wordlist_gen
```