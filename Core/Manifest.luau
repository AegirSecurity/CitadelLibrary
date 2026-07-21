--!strict
--!native
--!optimize 2
--/ Citadel/Core/Manifest.luau (Client) (a. HeartOfIrons)
--/ Manifestation database of components and other general information
return {
    Name = "Citadel (UI Library)";
    Version = {Std = "0.0.02:P"; Client = 103; API = 1} :: string;
    Compatibility = {Minimum = 100; Maximum = 105} :: {Minimum: number; Maximum: number};
    Dependencies = { --/ Allows `Root = {Package}` -> Project/Package and/or `Category = {Package}` -> Project/Category/Package.
        Tools = {"Signal"}
    } :: {[string]: {string}};
    Components = {} :: {string};
    Changelog = {} --/ TODO Create format for changelog
}