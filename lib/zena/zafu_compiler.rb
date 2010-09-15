require 'zafu'

module Zena
  # FIXME: replace with (and make sure all is ok!)
  # ZafuCompiler = Zafu.parser_with_rules(Zafu::All + Zena::Use.modules_for('Zafu'))

  ZafuCompiler = Zafu.parser_with_rules([
    Zafu::All,
    Zena::Use::Conditional::ZafuMethods,
    Zena::Use::Context::ZafuMethods,
    Zena::Use::Urls::ZafuMethods,
    Zena::Use::ZafuAttributes::ZafuMethods,
    Zena::Use::ZafuEval::ZafuMethods,
    Zena::Use::QueryBuilder::ZafuMethods,
    # Has to come after QB
    Zena::Use::Display::ZafuMethods,
    Zena::Use::I18n::ZafuMethods,
    Zena::Use::Action::ZafuMethods,
    Zena::Use::Dates::ZafuMethods,
    Zena::Use::Forms::ZafuMethods,
    Zena::Use::Recursion::ZafuMethods,
    Zena::Use::Search::ZafuMethods,
    Zena::Use::Ajax::ZafuMethods,
    Zena::Use::ZafuSafeDefinitions::ZafuMethods,
    Zena::Acts::Enrollable::ZafuMethods,
  ])

  Bricks.load_zafu(ZafuCompiler)
end