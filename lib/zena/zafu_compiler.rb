module Zena
  ZafuCompiler = Zafu.parser_with_rules(
    Zafu::All,
    Zena::Use::Display::ZafuMethods,
    Zena::Use::ZafuAttributes::ZafuMethods,
    Zena::Use::QueryBuilder::ZafuMethods
  )
end