(** Complétion de lignes de l'optimisation

L'optimisation a besoin d'une fonction pour connaître tous les
découpages possibles, à chaque ligne.
*)
open Box
open Line
open Util
open Break
open Document
(** {[normal]} measure paragraphs figures {already placed figures} {already placed user boxes}
{beginning of line to complete} {is this a desperate try ?} *)
let normal env paragraphs figures last_figures last_users line allow_impossible=
  let mes0=env.normalMeasure in
  let measure=
    let figures_=IntMap.filter (fun _ a->match a with Placed _->true |_->false) last_figures in
      if not (IntMap.is_empty figures_) then
        match IntMap.max_binding figures_ with
            (fig,Placed fig_line)->(
              if line.page=fig_line.page &&
                line.height<=
                fig_line.height -. figures.(fig).drawing_y0
                && line.height>=fig_line.height -. figures.(fig).drawing_y1
              then
                mes0 -. figures.(fig).drawing_nominal_width
              else
                mes0
            )
          | _->assert false
      else
        mes0
  in
  let rec break_next j sum_min sum_nom sum_max y0 y1 only_impossible result=
    if j>=Array.length paragraphs.(line.paragraph) then (

      if sum_min<=measure || (allow_impossible && only_impossible) then (
        { line with lineEnd=j; min_width=sum_min; nom_width=sum_nom; max_width=sum_max;
            line_y0=y0; line_y1=y1
        }::
          (if only_impossible then [] else result)
      ) else (
        if only_impossible && not allow_impossible then [] else result
      )
    ) else (
      let a,b,c=box_interval paragraphs.(line.paragraph).(j) in
      let y0'=lower_y paragraphs.(line.paragraph).(j) in
      let y1'=upper_y paragraphs.(line.paragraph).(j) in
      let result0=
        match paragraphs.(line.paragraph).(j) with
            Hyphen x when not allow_impossible->(
              let rec hyphenation k res=
                if k>=Array.length x.hyphenated then res else (
                  let (a',b',c')=boxes_interval (fst x.hyphenated.(k)) in
                  let y0''=Array.fold_left (fun x y->min x (lower_y y)) y0 (fst x.hyphenated.(k)) in
                  let y1''=Array.fold_left (fun x y->max x (upper_y y)) y1 (fst x.hyphenated.(k)) in
                    if sum_min+.a' <= measure && sum_max+.c' >= measure then
                      hyphenation (k+1)
                        ({ line with lineEnd=j; hyphenEnd=k; min_width=sum_min+.a';
                             nom_width=sum_nom+.b'; max_width=sum_max+.c';
                             line_y0=y0'';
                             line_y1=y1''
                         }::res)
                    else hyphenation (k+1) res)
              in
              hyphenation 0 [])
          | _ -> []
      in
        if sum_max >= measure || allow_impossible then
          match paragraphs.(line.paragraph).(j) with

              Glue _ when (sum_min <= measure) && j>line.lineStart ->
                break_next (j+1) (sum_min+.a) (sum_nom+.b) (sum_max+.c)
                  (min y0 y0') (max y1 y1')
                  (sum_max<measure && only_impossible)
                  ({ line with lineEnd=j; hyphenEnd=(-1); min_width=sum_min;
                       nom_width=sum_nom; max_width=sum_max;
                       line_y0=y0;
                       line_y1=y1;
                   }::(if only_impossible then [] else result))

            | Glue _ when allow_impossible && only_impossible && j>line.lineStart ->
                [{ line with lineEnd=j; hyphenEnd=(-1); min_width=sum_min;
                     nom_width=sum_nom; max_width=sum_max;
                     line_y0=y0;
                     line_y1=y1;
                 }]
            | _ ->
                break_next (j+1) (sum_min+. a) (sum_nom+.b) (sum_max+. c)
                  (min y0 y0') (max y1 y1')
                  (only_impossible && result0=[])
                  (result0@result)
        else
          break_next (j+1) (sum_min+. a) (sum_nom+.b) (sum_max+. c)
            (min y0 y0') (max y1 y1')
            (only_impossible && result0=[]) (result0@result)
    )
  in
    if line.hyphenStart>=0 then (
      match paragraphs.(line.paragraph).(line.lineStart) with
          Hyphen x->
            let a,b,c=boxes_interval (snd x.hyphenated.(line.hyphenStart)) in
            let y0=Array.fold_left (fun x y->min x (lower_y y)) infinity (snd x.hyphenated.(line.hyphenStart)) in
            let y1=Array.fold_left (fun x y->max x (upper_y y)) (-.infinity) (snd x.hyphenated.(line.hyphenStart)) in
            break_next (line.lineStart+1) a b c y0 y1 true []
        | _->break_next line.lineStart 0. 0. 0. infinity (-.infinity) true []
    ) else break_next line.lineStart 0. 0. 0. infinity (-.infinity) true []
