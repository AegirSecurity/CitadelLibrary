--!strict
--!native
--!optimize 2
--/ Citadel/Core/Manifest.luau (Client) (a. HeartOfIrons)
--/ Manifestation database of components and other general information
return {
    Name = "Citadel (UI Library)";
    Dependencies = { --/ Allows `Root = {Package}` -> Project/Package and/or `Category = {Package}` -> Project/Category/Package.
        Tools = {"Signal"}
    } :: {[string]: {string}};
    Components = {} :: {string};
    Changelog = {} --/ TODO Create format for changelog
}