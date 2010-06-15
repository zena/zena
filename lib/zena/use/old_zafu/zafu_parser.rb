# TODO: on cleanup only (all tests ok): remove this page

ZafuParser  = Zena::Parser.parser_with_rules(
  Zena::Parser::ZafuRules,
  Zena::Parser::ZenaRules,
  Zena::Parser::ZafuTags,
  Zafu::Action,
  Zafu::Ajax,
  Zafu::Attributes,
  Zafu::Calendar,
  Zafu::Context,
  Zafu::Core::HTML,
  Zafu::Core::MoveToParser,
  Zafu::Dates,
  Zafu::Display,
  Zafu::Eval,
  Zafu::Experimental,  # FIXME: remove and fix tests !
  Zafu::I18n,
  Zafu::Meta,
  Zafu::Refactor,
  Zafu::Support::Forms,
  Zafu::Support::Context,
  Zafu::Support::Dom,
  Zafu::Support::Erb,
  Zafu::Support::Flow,
  Zafu::Support::Links
)
