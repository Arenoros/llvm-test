//#include "ast.h"
//
////===----------------------------------------------------------------------===//
//// Parser
////===----------------------------------------------------------------------===//
//namespace ast {
//
//    /// CurTok/getNextToken - Provide a simple token buffer.  CurTok is the current
//    /// token the parser is looking at.  getNextToken reads another token from the
//    /// lexer and updates CurTok with its results.
//    
//    // enum class binary_op_t {
//    //    // 5
//    //    mul,   // *
//    //    div,   // /
//    //    rdiv,  // %
//    //    // 6
//    //    add,  // +
//    //    sub,  // -
//    //    // 7
//    //    rshift,  // >>
//    //    lshift,  // <<
//    //    // 9
//    //    lt,  // <
//    //    gt,  // >
//    //    le,  // <=
//    //    ge,  // >=
//    //    // 10
//    //    eq,  // ==
//    //    ne,  // !=
//    //    // 11
//    //    band,  // &
//    //    // 12
//    //    bxor,  // ^
//    //    // 13
//    //    bor,  // |
//
//    //    // 14
//    //    and_,  // &&
//    //    // 15
//    //    or_,  // ||
//    //};
//
//    /// BinopPrecedence - This holds the precedence for each binary operator that is
//    /// defined.
//    int BinopPrecedence(binary_op_t op) {
//        switch (op) {
//        case binary_op_t::mul:
//             return 5;
//        case binary_op_t::div:
//            return 5;
//        case binary_op_t::rdiv:
//            return 5;
//        case binary_op_t::sub:
//            return 6;
//        case binary_op_t::add:
//            return 6;
//        case binary_op_t::rshift:
//            break;
//        case binary_op_t::lshift:
//            break;
//        case binary_op_t::lt:
//            break;
//        case binary_op_t::gt:
//            break;
//        case binary_op_t::le:
//            break;
//        case binary_op_t::ge:
//            break;
//        case binary_op_t::eq:
//            break;
//        case binary_op_t::ne:
//            break;
//        case binary_op_t::band:
//            break;
//        case binary_op_t::bxor:
//            break;
//        case binary_op_t::bor:
//            break;
//        case binary_op_t::and_:
//            break;
//        case binary_op_t::or_:
//            break;
//        default: ;
//        }
//        return 0;
//    };
//
//    /// GetTokPrecedence - Get the precedence of the pending binary operator token.
//    //int GetTokPrecedence() {
//    //    if (!isascii(CurTok))
//    //        return -1;
//
//    //    // Make sure it's a declared binop.
//    //    int TokPrec = BinopPrecedence[CurTok];
//    //    if (TokPrec <= 0)
//    //        return -1;
//    //    return TokPrec;
//    //}
//
//    ///// LogError* - These are little helper functions for error handling.
//    //std::unique_ptr<expr_node_t> log_error(const char* Str) {
//    //    fprintf(stderr, "Error: %s\n", Str);
//    //    return nullptr;
//    //}
//
//    //std::unique_ptr<prototype_ast_t> log_error_p(const char* Str) {
//    //    log_error(Str);
//    //    return nullptr;
//    //}
//
//    ///// numberexpr ::= number
//    //std::unique_ptr<expr_node_t> parse_int64_expr() {
//    //    auto Result = std::make_unique<int64_expr_t>(NumVal);
//    //    getNextToken();  // consume the number
//    //    return std::move(Result);
//    //}
//
//    ///// numberexpr ::= number
//    //std::unique_ptr<expr_node_t> parse_float64_expr() {
//    //    auto Result = std::make_unique<float64_expr_t>(NumVal);
//    //    getNextToken();  // consume the number
//    //    return std::move(Result);
//    //}
//
//    ///// parenexpr ::= '(' expression ')'
//    //std::unique_ptr<expr_node_t> parse_paren_expr() {
//    //    getNextToken();  // eat (.
//    //    auto V = parse_expression();
//    //    if (!V)
//    //        return nullptr;
//
//    //    if (CurTok != ')')
//    //        return log_error("expected ')'");
//    //    getNextToken();  // eat ).
//    //    return V;
//    //}
//
//    ///// identifierexpr
//    /////   ::= identifier
//    /////   ::= identifier '(' expression* ')'
//    //std::unique_ptr<expr_node_t> parse_identifier_expr() {
//    //    std::string IdName = IdentifierStr;
//
//    //    getNextToken();  // eat identifier.
//
//    //    if (CurTok != '(')  // Simple variable ref.
//    //        return std::make_unique<variable_expr_t>(IdName);
//
//    //    // Call.
//    //    getNextToken();  // eat (
//    //    std::vector<std::unique_ptr<expr_node_t>> Args;
//    //    if (CurTok != ')') {
//    //        while (true) {
//    //            if (auto Arg = parse_expression())
//    //                Args.push_back(std::move(Arg));
//    //            else
//    //                return nullptr;
//
//    //            if (CurTok == ')')
//    //                break;
//
//    //            if (CurTok != ',')
//    //                return log_error("Expected ')' or ',' in argument list");
//    //            getNextToken();
//    //        }
//    //    }
//
//    //    // Eat the ')'.
//    //    getNextToken();
//
//    //    return std::make_unique<call_expr_t>(IdName, std::move(Args));
//    //}
//
//    ///// ifexpr ::= 'if' expression 'then' expression 'else' expression
//    //std::unique_ptr<expr_node_t> parse_if_expr() {
//    //    getNextToken();  // eat the if.
//
//    //    // condition.
//    //    auto Cond = parse_expression();
//    //    if (!Cond)
//    //        return nullptr;
//
//    //    if (CurTok != tok_then)
//    //        return log_error("expected then");
//    //    getNextToken();  // eat the then
//
//    //    auto Then = parse_expression();
//    //    if (!Then)
//    //        return nullptr;
//
//    //    if (CurTok != tok_else)
//    //        return log_error("expected else");
//
//    //    getNextToken();
//
//    //    auto Else = parse_expression();
//    //    if (!Else)
//    //        return nullptr;
//
//    //    return std::make_unique<if_expr_t>(std::move(Cond), std::move(Then), std::move(Else));
//    //}
//
//    ///// forexpr ::= 'for' identifier '=' expr ',' expr (',' expr)? 'in' expression
//    //std::unique_ptr<expr_node_t> parse_for_expr() {
//    //    getNextToken();  // eat the for.
//
//    //    if (CurTok != tok_identifier)
//    //        return log_error("expected identifier after for");
//
//    //    std::string IdName = IdentifierStr;
//    //    getNextToken();  // eat identifier.
//
//    //    if (CurTok != '=')
//    //        return log_error("expected '=' after for");
//    //    getNextToken();  // eat '='.
//
//    //    auto Start = parse_expression();
//    //    if (!Start)
//    //        return nullptr;
//    //    if (CurTok != ',')
//    //        return log_error("expected ',' after for start value");
//    //    getNextToken();
//
//    //    auto End = parse_expression();
//    //    if (!End)
//    //        return nullptr;
//
//    //    // The step value is optional.
//    //    std::unique_ptr<expr_node_t> Step;
//    //    if (CurTok == ',') {
//    //        getNextToken();
//    //        Step = parse_expression();
//    //        if (!Step)
//    //            return nullptr;
//    //    }
//
//    //    if (CurTok != tok_in)
//    //        return log_error("expected 'in' after for");
//    //    getNextToken();  // eat 'in'.
//
//    //    auto Body = parse_expression();
//    //    if (!Body)
//    //        return nullptr;
//
//    //    return std::make_unique<for_expr_t>(IdName, std::move(Start), std::move(End), std::move(Step), std::move(Body));
//    //}
//
//    ///// varexpr ::= 'var' identifier ('=' expression)?
//    ////                    (',' identifier ('=' expression)?)* 'in' expression
//    //std::unique_ptr<expr_node_t> parse_var_expr() {
//    //    getNextToken();  // eat the var.
//
//    //    std::vector<std::pair<std::string, std::unique_ptr<expr_node_t>>> VarNames;
//
//    //    // At least one variable name is required.
//    //    if (CurTok != tok_identifier)
//    //        return log_error("expected identifier after var");
//
//    //    while (true) {
//    //        std::string Name = IdentifierStr;
//    //        getNextToken();  // eat identifier.
//
//    //        // Read the optional initializer.
//    //        std::unique_ptr<expr_node_t> Init = nullptr;
//    //        if (CurTok == '=') {
//    //            getNextToken();  // eat the '='.
//
//    //            Init = parse_expression();
//    //            if (!Init)
//    //                return nullptr;
//    //        }
//
//    //        VarNames.push_back(std::make_pair(Name, std::move(Init)));
//
//    //        // End of var list, exit loop.
//    //        if (CurTok != ',')
//    //            break;
//    //        getNextToken();  // eat the ','.
//
//    //        if (CurTok != tok_identifier)
//    //            return log_error("expected identifier list after var");
//    //    }
//
//    //    // At this point, we have to have 'in'.
//    //    if (CurTok != tok_in)
//    //        return log_error("expected 'in' keyword after 'var'");
//    //    getNextToken();  // eat 'in'.
//
//    //    auto Body = parse_expression();
//    //    if (!Body)
//    //        return nullptr;
//
//    //    return std::make_unique<vardef_expr_t>(std::move(VarNames), std::move(Body));
//    //}
//
//    ///// primary
//    /////   ::= identifierexpr
//    /////   ::= numberexpr
//    /////   ::= parenexpr
//    /////   ::= ifexpr
//    /////   ::= forexpr
//    /////   ::= varexpr
//    //std::unique_ptr<expr_node_t> parse_primary() {
//    //    switch (CurTok) {
//    //    default:
//    //        return log_error("unknown token when expecting an expression");
//    //    case tok_identifier:
//    //        return parse_identifier_expr();
//    //    case tok_number:
//    //        return parse_number_expr();
//    //    case '(':
//    //        return parse_paren_expr();
//    //    case tok_if:
//    //        return parse_if_expr();
//    //    case tok_for:
//    //        return parse_for_expr();
//    //    case tok_var:
//    //        return parse_var_expr();
//    //    }
//    //}
//
//    ///// unary
//    /////   ::= primary
//    /////   ::= '!' unary
//    //std::unique_ptr<expr_node_t> parse_unary() {
//    //    // If the current token is not an operator, it must be a primary expr.
//    //    if (!isascii(CurTok) || CurTok == '(' || CurTok == ',')
//    //        return parse_primary();
//
//    //    // If this is a unary operator, read it.
//    //    int Opc = CurTok;
//    //    getNextToken();
//    //    if (auto Operand = parse_unary())
//    //        return std::make_unique<unary_expr_t>(Opc, std::move(Operand));
//    //    return nullptr;
//    //}
//
//    ///// binoprhs
//    /////   ::= ('+' unary)*
//    //std::unique_ptr<expr_node_t> parse_bin_op_rhs(int ExprPrec, std::unique_ptr<expr_node_t> LHS) {
//    //    // If this is a binop, find its precedence.
//    //    while (true) {
//    //        int TokPrec = GetTokPrecedence();
//
//    //        // If this is a binop that binds at least as tightly as the current binop,
//    //        // consume it, otherwise we are done.
//    //        if (TokPrec < ExprPrec)
//    //            return LHS;
//
//    //        // Okay, we know this is a binop.
//    //        int BinOp = CurTok;
//    //        getNextToken();  // eat binop
//
//    //        // Parse the unary expression after the binary operator.
//    //        auto RHS = parse_unary();
//    //        if (!RHS)
//    //            return nullptr;
//
//    //        // If BinOp binds less tightly with RHS than the operator after RHS, let
//    //        // the pending operator take RHS as its LHS.
//    //        int NextPrec = GetTokPrecedence();
//    //        if (TokPrec < NextPrec) {
//    //            RHS = parse_bin_op_rhs(TokPrec + 1, std::move(RHS));
//    //            if (!RHS)
//    //                return nullptr;
//    //        }
//
//    //        // Merge LHS/RHS.
//    //        LHS = std::make_unique<binary_expr_t>(BinOp, std::move(LHS), std::move(RHS));
//    //    }
//    //}
//
//    ///// expression
//    /////   ::= unary binoprhs
//    /////
//    //std::unique_ptr<expr_node_t> parse_expression() {
//    //    auto LHS = parse_unary();
//    //    if (!LHS)
//    //        return nullptr;
//
//    //    return parse_bin_op_rhs(0, std::move(LHS));
//    //}
//
//    ///// prototype
//    /////   ::= id '(' id* ')'
//    /////   ::= binary LETTER number? (id, id)
//    /////   ::= unary LETTER (id)
//    //std::unique_ptr<prototype_ast_t> parse_prototype() {
//    //    std::string FnName;
//
//    //    unsigned Kind = 0;  // 0 = identifier, 1 = unary, 2 = binary.
//    //    unsigned BinaryPrecedence = 30;
//
//    //    switch (CurTok) {
//    //    default:
//    //        return log_error_p("Expected function name in prototype");
//    //    case tok_identifier:
//    //        FnName = IdentifierStr;
//    //        Kind = 0;
//    //        getNextToken();
//    //        break;
//    //    case tok_unary:
//    //        getNextToken();
//    //        if (!isascii(CurTok))
//    //            return log_error_p("Expected unary operator");
//    //        FnName = "unary";
//    //        FnName += (char)CurTok;
//    //        Kind = 1;
//    //        getNextToken();
//    //        break;
//    //    case tok_binary:
//    //        getNextToken();
//    //        if (!isascii(CurTok))
//    //            return log_error_p("Expected binary operator");
//    //        FnName = "binary";
//    //        FnName += (char)CurTok;
//    //        Kind = 2;
//    //        getNextToken();
//
//    //        // Read the precedence if present.
//    //        if (CurTok == tok_number) {
//    //            if (NumVal < 1 || NumVal > 100)
//    //                return log_error_p("Invalid precedence: must be 1..100");
//    //            BinaryPrecedence = (unsigned)NumVal;
//    //            getNextToken();
//    //        }
//    //        break;
//    //    }
//
//    //    if (CurTok != '(')
//    //        return log_error_p("Expected '(' in prototype");
//
//    //    std::vector<std::string> ArgNames;
//    //    while (getNextToken() == tok_identifier)
//    //        ArgNames.push_back(IdentifierStr);
//    //    if (CurTok != ')')
//    //        return log_error_p("Expected ')' in prototype");
//
//    //    // success.
//    //    getNextToken();  // eat ')'.
//
//    //    // Verify right number of names for operator.
//    //    if (Kind && ArgNames.size() != Kind)
//    //        return log_error_p("Invalid number of operands for operator");
//
//    //    return std::make_unique<prototype_ast_t>(FnName, ArgNames, Kind != 0, BinaryPrecedence);
//    //}
//
//    ///// definition ::= 'def' prototype expression
//    //std::unique_ptr<function_ast> parse_definition() {
//    //    getNextToken();  // eat def.
//    //    auto Proto = parse_prototype();
//    //    if (!Proto)
//    //        return nullptr;
//
//    //    if (auto E = parse_expression())
//    //        return std::make_unique<function_ast>(std::move(Proto), std::move(E));
//    //    return nullptr;
//    //}
//
//    ///// toplevelexpr ::= expression
//    //std::unique_ptr<function_ast> parse_top_level_expr() {
//    //    if (auto E = parse_expression()) {
//    //        // Make an anonymous proto.
//    //        auto Proto = std::make_unique<prototype_ast_t>("__anon_expr", std::vector<std::string>());
//    //        return std::make_unique<function_ast>(std::move(Proto), std::move(E));
//    //    }
//    //    return nullptr;
//    //}
//
//    ///// external ::= 'extern' prototype
//    //std::unique_ptr<prototype_ast_t> parse_extern() {
//    //    getNextToken();  // eat extern.
//    //    return parse_prototype();
//    //}
//}  // namespace ast