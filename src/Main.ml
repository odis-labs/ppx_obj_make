open Migrate_parsetree
open Ast_406
open Ast_mapper
open Ast_helper
open Asttypes
open Parsetree
open Longident


let fail loc s =
  raise (Location.Error (Location.error ~loc ("ppx_make_record: " ^ s)))


let mk_func ~loc longident =
  let l = Longident.flatten longident in
  let l = List.append l ["make"] in
  (* TODO: Extend the loc col num to include "make". *)
  let longident =
    match Longident.unflatten l with
    | Some lid -> lid
    | None -> failwith (Printf.sprintf "Invalid longident: [%s]" (String.concat "." l)) in
  Exp.ident (Location.mkloc longident loc)

let unit ?loc () =
  Exp.construct ?loc (Location.mknoloc (Lident "()")) None

let should_rewrite = ref false

let rec expr mapper e =
  match e.pexp_desc with
  | Pexp_extension ({txt="make"; _}, PStr [{pstr_desc = Pstr_eval(x, _); _}]) ->
    should_rewrite := true;
    let e' = expr mapper x in
    should_rewrite := false;
    e'

  | Pexp_extension ({txt="make"; loc}, _) ->
    fail loc "requires an expression"

  | Pexp_construct (
      {txt=longident; loc},
      Some ({pexp_desc=Pexp_record (fields, None); _})
    ) when !should_rewrite ->
    let field_to_arg field =
      match field with
      | ({txt=Lident name; _}, value) -> (Labelled name, expr mapper value)
      | _ -> assert false (* invalid field name *) in
    let args = List.append (List.map field_to_arg fields) [(Nolabel, unit ())] in
    Exp.apply ~loc (mk_func ~loc longident) args

  | Pexp_construct(
      {txt=longident; loc},
      Some ({pexp_desc=Pexp_construct ({txt=Lident "()"; _}, None); _})
    ) when !should_rewrite ->
    let args = [(Nolabel, unit ())] in
    Exp.apply ~loc (mk_func ~loc longident) args

  | _ -> default_mapper.expr mapper e


let rec structure mapper items =
  match items with
  | {pstr_desc = Pstr_extension (
      ({txt="make"; loc=_}, PStr [{pstr_desc = Pstr_value(rec_flag, bindings); _}]), _); _ }
    :: items' ->
    should_rewrite := true;
    let bindings' =
      List.map
        (fun binding -> { binding with pvb_expr = expr mapper binding.pvb_expr })
        bindings
    in
    should_rewrite := false;
    let item' = Str.value rec_flag bindings' in
    item' :: structure mapper items'

  | item :: items ->
    mapper.structure_item mapper item :: structure mapper items

  | [] -> []


let () =
  let rewriter _config _cookies = { default_mapper with expr; structure } in
  Driver.register ~name:"ppx_make_record" Versions.ocaml_406 rewriter

