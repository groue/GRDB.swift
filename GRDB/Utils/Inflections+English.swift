// Copyright (C) 2015-2020 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// =============================================================================
//
// Copyright (c) 2005-2019 David Heinemeier Hansson
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

extension Inflections {
    /// The default inflections
    public static var `default`: Inflections = {
        // Defines the standard inflection rules. These are the starting point
        // for new projects and are not considered complete. The current set of
        // inflection rules is frozen. This means, we do not change them to
        // become more complete. This is a safety measure to keep existing
        // applications from breaking.
        //
        // https://github.com/rails/rails/blob/b2eb1d1c55a59fee1e6c4cba7030d8ceb524267c/activesupport/lib/active_support/inflections.rb
        var inflections = Inflections()
        
        inflections.plural("$", "s")
        inflections.plural("s$", "s")
        inflections.plural("^(ax|test)is$", "$1es")
        inflections.plural("(octop|vir)us$", "$1i")
        inflections.plural("(octop|vir)i$", "$1i")
        inflections.plural("(alias|status)$", "$1es")
        inflections.plural("(bu)s$", "$1ses")
        inflections.plural("(buffal|tomat|her)o$", "$1oes")
        inflections.plural("([ti])um$", "$1a")
        inflections.plural("([ti])a$", "$1a")
        inflections.plural("sis$", "ses")
        inflections.plural("(?:([^f])fe|([lr])f)$", "$1$2ves")
        inflections.plural("(hive)$", "$1s")
        inflections.plural("([^aeiouy]|qu)y$", "$1ies")
        inflections.plural("(x|ch|ss|sh)$", "$1es")
        inflections.plural("(matr|vert|ind)(?:ix|ex)$", "$1ices")
        inflections.plural("^(m|l)ouse$", "$1ice")
        inflections.plural("^(m|l)ice$", "$1ice")
        inflections.plural("^(ox)$", "$1en")
        inflections.plural("^(oxen)$", "$1")
        inflections.plural("(quiz)$", "$1zes")
        inflections.plural("(canva)s$", "$1ses")
        
        inflections.singular("s$", "")
        inflections.singular("(ss)$", "$1")
        inflections.singular("(n)ews$", "$1ews")
        inflections.singular("([ti])a$", "$1um")
        inflections.singular("((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)(sis|ses)$", "$1sis")
        inflections.singular("(^analy)(sis|ses)$", "$1sis")
        inflections.singular("([^f])ves$", "$1fe")
        inflections.singular("(hive)s$", "$1")
        inflections.singular("(tive)s$", "$1")
        inflections.singular("([lr])ves$", "$1f")
        inflections.singular("([^aeiouy]|qu)ies$", "$1y")
        inflections.singular("(s)eries$", "$1eries")
        inflections.singular("(m)ovies$", "$1ovie")
        inflections.singular("(x|ch|ss|sh)es$", "$1")
        inflections.singular("^(m|l)ice$", "$1ouse")
        inflections.singular("(bus)(es)?$", "$1")
        inflections.singular("(o)es$", "$1")
        inflections.singular("(shoe)s$", "$1")
        inflections.singular("(cris|test)(is|es)$", "$1is")
        inflections.singular("^(a)x[ie]s$", "$1xis")
        inflections.singular("(octop|vir)(us|i)$", "$1us")
        inflections.singular("(alias|status)(es)?$", "$1")
        inflections.singular("^(ox)en$", "$1")
        inflections.singular("(vert|ind)ices$", "$1ex")
        inflections.singular("(matr)ices$", "$1ix")
        inflections.singular("(quiz)zes$", "$1")
        inflections.singular("(database)s$", "$1")
        inflections.singular("(canvas)(es)?$", "$1")
        
        inflections.uncountableWords([
            "advice",
            "corps",
            "dice",
            "equipment",
            "fish",
            "information",
            "jeans",
            "kudos",
            "money",
            "offspring",
            "police",
            "rice",
            "sheep",
            "species",
        ])
        
        inflections.irregularSuffix("child", "children")
        inflections.irregularSuffix("foot", "feet")
        inflections.irregularSuffix("leaf", "leaves")
        inflections.irregularSuffix("man", "men")
        inflections.irregularSuffix("move", "moves")
        inflections.irregularSuffix("person", "people")
        inflections.irregularSuffix("sex", "sexes")
        inflections.irregularSuffix("specimen", "specimens")
        inflections.irregularSuffix("zombie", "zombies")
        
        return inflections
    }()
}
