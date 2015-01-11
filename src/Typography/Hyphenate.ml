(*
  Copyright Florian Hatat, Tom Hirschowitz, Pierre Hyvernat,
  Pierre-Etienne Meunier, Christophe Raffalli, Guillaume Theyssier 2012.

  This file is part of Patoline.

  Patoline is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Patoline is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Patoline.  If not, see <http://www.gnu.org/licenses/>.
*)

type ptree=
    Node of (string)*(ptree UChar.UMap.t)
  | Exception of (string list)*(ptree UChar.UMap.t)

let is_num c = c>=int_of_char '0' && c<=int_of_char '9'

let insert tree a=
  let breaks0=String.make (String.length a) '0' in
  let j=ref 0 in

  let rec fill_breaks i=
    if i<String.length a then (
      let c=UChar.code (UTF8.look a i) in
      if is_num c then (
        breaks0.[i- !j]<-char_of_int (c-int_of_char '0');
        incr j
      );
      fill_breaks (UTF8.next a i)
    )
  in
  fill_breaks 0;

  let breaks=String.sub breaks0 0 (String.length breaks0 - !j) in
  let rec insert i tree=
    if i>=String.length a then (
      match tree with
          Node (_,t)->Node (breaks, t)
        | _->tree                       (* Si ce motif est déjà une exception, on ne fait rien *)
    ) else (
      if is_num (UChar.code (UTF8.look a i)) then
        insert (UTF8.next a i) tree
      else
        (match tree with
            Node (x,t)->
              (let tree'=try UChar.UMap.find (UTF8.look a i) t with Not_found->Node ("", UChar.UMap.empty) in
               Node (x, UChar.UMap.add (UTF8.look a i) (insert (UTF8.next a i) tree') t))
          | Exception (x,t)->
            (let tree'=try UChar.UMap.find (UTF8.look a i) t with Not_found->Node ("", UChar.UMap.empty) in
             Exception (x, UChar.UMap.add (UTF8.look a i) (insert (UTF8.next a i) tree') t))
        )
    )
  in
  insert 0 tree

let insert_exception tree a0=
  let a="."^(List.fold_left (^) "" a0)^"." in

  let rec insert i = function
      Exception (_,_) as t when i>=String.length a-1 -> t
    | Exception (x,t)->(
      let t'=try UChar.UMap.find (UTF8.look a i) t with Not_found->Node ("", UChar.UMap.empty) in
      Exception (x, UChar.UMap.add (UTF8.look a i) (insert (UTF8.next a i) t') t)
    )
    | Node (x,t) when i>=String.length a-1 -> Exception (a0,t)
    | Node (x,t)->(
      let t'=try UChar.UMap.find (UTF8.look a i) t with Not_found->Node ("", UChar.UMap.empty) in
      Node (x, UChar.UMap.add (UTF8.look a i) (insert (UTF8.next a i) t') t)
    )
  in
    insert 0 tree


exception Exp of (string list)

let rec dash_hyphen s i acc=
  if i>=String.length s then acc else
    let j,next=
      try
        let i'=String.index_from s i '-' in
        if i'>=String.length s-1 then (String.length s,acc) else (
          let s0=String.sub s 0 (i'+1) in
          let s1=String.sub s (i'+1) (String.length s-i'-1) in
          (i'+1),((s0,s1)::acc)
        )
      with
        Not_found->String.length s,acc
    in
    dash_hyphen s j next

let hyphenate tree a0=
  if UTF8.length a0<=4 then [] else
    let rec find_punct i=
      if i>=String.length a0 then i else
        match UCharInfo.general_category (UTF8.look a0 i) with
            UCharInfo.Cc
          | UCharInfo.Cf
          | UCharInfo.Cn
          | UCharInfo.Co
          | UCharInfo.Cs
              (*
          | UCharInfo.Mc
          | UCharInfo.Me
          | UCharInfo.Mn
              *)
          | UCharInfo.Pc
          | UCharInfo.Pd
          | UCharInfo.Pe
          | UCharInfo.Pf
          | UCharInfo.Pi
          | UCharInfo.Po
          | UCharInfo.Ps
          | UCharInfo.Zl
          | UCharInfo.Zp
          | UCharInfo.Zs -> i
          | _->find_punct (UTF8.next a0 i)
    in
    let first_punct=find_punct 0 in
    match dash_hyphen a0 0 [] with
      _::_ as l->l
    | _->(
        let a=String.create (first_punct+2) in
        String.blit a0 0 a 1 first_punct;
        a.[0]<-'.';
        a.[String.length a-1]<-'.';
        let breaks=String.make (String.length a+1) (char_of_int 0) in
        let rec hyphenate i j t=if j<=String.length a then
            match t with
              | Exception (x,_) when i=0 && j=String.length a-1->(
                (* raise (Exp x) *)
                ()
              )
              | Exception (_,t)->
                (
                  try
                    let t'=UChar.UMap.find (UTF8.look a j) t in
                    hyphenate i (UTF8.next a j) t'
                  with
                      _->())
              | Node (x,t) -> (
                if String.length x>0 then (
                  let rec fill_breaks k=
                    breaks.[i+k]<-max breaks.[i+k] x.[k];
                    fill_breaks (UTF8.next a (i+k)-i)
                  in
                  fill_breaks 0
                );
                try
                  let t'=UChar.UMap.find (UTF8.look a j) t in
                  hyphenate i (UTF8.next a j) t'
                with
                    _->()
              )
        in

        let rec hyphenate_word i=
          if i<String.length a then (
            hyphenate i i tree;
            hyphenate_word (UTF8.next a i)
          )
        in
        hyphenate_word 0;

        let total=UTF8.length a in
        let rec make_hyphens j k=
          if j>=String.length a || j+1>=String.length breaks || total-k<6 then
            [] else (
            if (int_of_char breaks.[j+1]) land 1 = 1 && k>=3 then (
              let j'=(UTF8.next a j-1) in
              (String.sub a0 0 j'^"-",String.sub a0 j' (String.length a0-j')) ::
                make_hyphens (UTF8.next a j) (k+1)
            )
            else
              make_hyphens (UTF8.next a j) (k+1)
          )
        in
        let m=make_hyphens 1 0 in
        m
      )
let empty=Node ("", UChar.UMap.empty)

#ifdef DEBUG
let _=
    let i=open_in_bin ("../../Hyphenation/hyph-en-us.hdict") in
    let tree=input_value i in
    close_in i;
  (* let tree0 = List.fold_left insert (Node ([||],UChar.UMap.empty)) ["ab3sent.";"2sent."] in *)
  (* let tree = List.fold_left insert_exception tree0 [] in *)
    List.iter (fun a->
      Printf.fprintf stderr "%S\n" a
    )  (hyphenate tree "algorithms;")
#endif
