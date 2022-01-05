#pragma once
#include "ast.h"

#define SYM_LIST(class_name_c, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_TOKEN(class_name_c, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF0(class_name_c, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF1(class_name_c, ref1, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF2(class_name_c, ref1, ref2, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF3(class_name_c, ref1, ref2, ref3, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF4(class_name_c, ref1, ref2, ref3, ref4, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF5(class_name_c, ref1, ref2, ref3, ref4, ref5, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF6(class_name_c, ref1, ref2, ref3, ref4, ref5, ref6, ...) virtual void* visit(class_name_c* symbol) = 0;

class visitor_c {
public:
#include "absyntax.def"

    virtual ~visitor_c(void);
};

#undef SYM_LIST
#undef SYM_TOKEN
#undef SYM_REF0
#undef SYM_REF1
#undef SYM_REF2
#undef SYM_REF3
#undef SYM_REF4
#undef SYM_REF5
#undef SYM_REF6

#define SYM_LIST(class_name_c, ...) virtual void* visit(class_name_c* symbol);
#define SYM_TOKEN(class_name_c, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF0(class_name_c, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF1(class_name_c, ref1, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF2(class_name_c, ref1, ref2, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF3(class_name_c, ref1, ref2, ref3, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF4(class_name_c, ref1, ref2, ref3, ref4, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF5(class_name_c, ref1, ref2, ref3, ref4, ref5, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF6(class_name_c, ref1, ref2, ref3, ref4, ref5, ref6, ...) virtual void* visit(class_name_c* symbol);

class null_visitor_c : public visitor_c {
public:
#include "absyntax.def"

    virtual ~null_visitor_c(void);
};

class fcall_visitor_c : public visitor_c {
public:
    virtual void fcall(symbol_c* symbol) = 0;

public:
  #include "absyntax.def"
  virtual ~fcall_visitor_c(void);
};

class iterator_visitor_c : public visitor_c {
protected:
    void* visit_list(list_c* list);

public:
#include "absyntax.def"

    virtual ~iterator_visitor_c(void);
};

class fcall_iterator_visitor_c : public iterator_visitor_c {
public:
    virtual void prefix_fcall(symbol_c* symbol);
    virtual void suffix_fcall(symbol_c* symbol);

public:
#include "absyntax.def"

    virtual ~fcall_iterator_visitor_c(void);
};

class search_visitor_c : public visitor_c {
protected:
    void* visit_list(list_c* list);

public:
#include "absyntax.def"

    virtual ~search_visitor_c(void);
};

#undef SYM_LIST
#undef SYM_TOKEN
#undef SYM_REF0
#undef SYM_REF1
#undef SYM_REF2
#undef SYM_REF3
#undef SYM_REF4
#undef SYM_REF5
#undef SYM_REF6
