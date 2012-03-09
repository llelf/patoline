open Drivers
open Binary
open Constants
open Lexing
open Util
open Fonts
open Fonts.FTypes
open Parser

let spec = []

let preambule = "
  open Typography
  open Parameters
  open Fonts.FTypes
  open Util
  open Fonts
  open Drivers
  open DefaultFormat;;

"

let postambule : ('a, 'b, 'c) format = "
  let gr=open_out \"doc_graph\" in
    doc_graph gr !str;
    close_out gr;

  let params,compl,pars=flatten defaultEnv !str in
  let (_,pages)=Typeset.typeset
    ~completeLine:compl
    ~parameters:params
    ~badness:(Badness.badness pars)
    pars
  in
  let u,v=Output.routine pars [||] defaultEnv pages in
    Drivers.Pdf.output ~structure:(make_struct v !str) u \"%s.pdf\" 
" 

let rec print_macro ch op mtype name args =
  begin
    match mtype with
    | `Single -> Printf.fprintf ch "%s" name
    | `Begin -> Printf.fprintf ch "module TEMP = struct\n open Env_%s;;\n do_begin_%s" name name
    | `End -> Printf.fprintf ch "do_end_%s" name
  end;
  List.iter (function
    Paragraph p -> Printf.fprintf ch " %a" (print_contents op) p
  | Caml(s,e) ->
    let size = e - s in
    let buf=String.create size in
    let _= seek_in op s; input op buf 0 size in
    Printf.fprintf ch " (%s)" buf
  | _ -> assert false) args;
  if args = [] then Printf.fprintf ch " ()";
  if mtype = `End then Printf.fprintf ch "\nend"

and print_contents op ch l = 
  Printf.fprintf ch "(";
  begin match l with
    [] ->  Printf.fprintf ch "[]";
  | TC s :: l -> 
    Printf.fprintf ch "(T \"%s\")::" (String.escaped s);
    print_contents op ch l
  | MC(mtype, name, args) :: l -> 
    Printf.fprintf ch "(";
    print_macro ch op mtype name args;
    Printf.fprintf ch ")@";
    print_contents op ch l
  end;
  Printf.fprintf ch ")"

let _=
  let filename=ref [] in
    Arg.parse spec (fun x->filename:=x::(!filename)) "Usage :";
    try
      match !filename with
          []-> Printf.printf "no input files\n"
        | h::_->
            let op=open_in h in
            let lexbuf = Dyp.from_channel (Parser.pp ()) op in
            try
	      let docs = Parser.main lexbuf in
	      match docs with
	        [] | (_::_::_) -> assert false
	      | [(pre, docs), _] ->
		  Printf.printf "%s" preambule;
		  begin match pre with
		    None -> ()
		  | Some(title, at) -> 
		      Printf.printf "title %b %a;;\n\n" (at = None) (print_contents op) title;
		      match at with
			None -> ()
		      | Some(auth,inst) ->
			Printf.printf "author %b %a;;\n\n" (inst = None) (print_contents op) auth;
			  match inst with
			    None -> ()
			  | Some(inst) ->
			    Printf.printf "institute true %a;;\n\n" (print_contents op) inst
		  end;
		  let rec output_list docs = List.iter output_doc docs
		  and output_doc = function
		    | Paragraph p ->
		      Printf.printf "newPar textWidth parameters %a;;\n" 
			(print_contents op) p
		    | Caml(s,e) ->
		      let size = e - s in
		      let buf=String.create size in
		      let _= seek_in op s; input op buf 0 size in
		      Printf.printf "%s;;\n\n" buf
		    | Struct(title, docs) ->
		      Printf.printf "newStruct %a;;\n\n" (print_contents op) title;
		      output_list docs;
		      Printf.printf "up();;\n\n"
		    | Macro(mtype, name, args) ->
		      print_macro stdout op mtype name args;
		      Printf.printf ";;\n\n" 
		  in
		  output_list docs;
		  close_in op;
		  Printf.printf postambule (Filename.chop_extension h)
	    with
	    | Dyp.Syntax_error ->
	      raise
	        (Syntax_Error (Dyp.lexeme_start_p lexbuf,
			       "parsing error"))
	    | Failure("lexing: empty token") ->
	      raise
	        (Syntax_Error (Dyp.lexeme_start_p lexbuf,
			       "unexpected char"))
    with
        Syntax_Error(pos,msg) ->
	  Printf.printf "%s:%d,%d %s\n" pos.pos_fname pos.pos_lnum (pos.pos_cnum - pos.pos_bol) msg
