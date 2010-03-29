require 'zafu'

module Zena
  ZafuCompiler = Zafu.parser_with_rules([
    Zafu::All,
    Zena::Use::Conditional::ZafuMethods,
    Zena::Use::Display::ZafuMethods,
    Zena::Use::Urls::ZafuMethods,
    Zena::Use::ZafuAttributes::ZafuMethods,
    Zena::Use::ZafuEval::ZafuMethods,
    Zena::Use::QueryBuilder::ZafuMethods,
    Zena::Use::I18n::ZafuMethods,
    Zena::Use::Action::ZafuMethods,
  ])
end