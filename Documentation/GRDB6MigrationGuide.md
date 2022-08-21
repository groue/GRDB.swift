Migrating From GRDB 5 to GRDB 6
===============================

**This guide aims at helping you upgrading your applications from GRDB 5 to GRDB 6.**

- [Preparing the Migration to GRDB 6](#preparing-the-migration-to-grdb-6)


## Preparing the Migration to GRDB 6

If you haven't made it yet, upgrade to the [latest GRDB 5 release](https://github.com/groue/GRDB.swift/tags) first, and fix any deprecation warning prior to the GRDB 6 upgrade.

You can then upgrade to GRDB 6. Due to the breaking changes, it is possible that your application code no longer compiles. Follow the fix-its that suggest simple syntactic changes. Other modifications that you need to apply are described below.
