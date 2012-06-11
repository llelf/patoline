open Bezier
open FTypes
open CamomileLibrary


exception Not_supported

module FTypes=FTypes

module type Font=FTypes.Font
module Opentype=Opentype
module CFF=CFF

module Opentype_=(Opentype:Font)
module CFF_=(CFF:Font)

(** loadFont pretends it can recognize font file types, but it
    actually only looks at the extension in the file name *)
type font = CFF of CFF.font | Opentype of Opentype.font
type glyph = CFFGlyph of CFF.glyph | OpentypeGlyph of Opentype.glyph


let fontName f=
  match f with
      CFF x->CFF.fontName x
    | Opentype x->Opentype.fontName x

#ifdef BAN_COMIC_SANS
exception Comic_sans
#endif

let loadFont ?offset:(off=0) ?size:(_=0) f=
  let size=let i=Util.open_in_bin_cached f in in_channel_length i in
  let font=if Filename.check_suffix f ".otf" then
    Opentype (Opentype.loadFont ~offset:off f ~size:size)
  else
    raise Not_supported
  in
#ifdef BAN_COMIC_SANS
  let low=(String.lowercase (fontName font)) in
  let comic=Util.is_substring "comic" low 0 in
    if comic<0 then font else
      let sans=Util.is_substring "sans" low comic in
        if sans<0 then font else
          raise Comic_sans
#else
    font
#endif

let glyph_of_uchar f c=
  match f with
      CFF x->CFF.glyph_of_uchar x c
    | Opentype x->Opentype.glyph_of_uchar x c
let glyph_of_char f c=glyph_of_uchar f (UChar.of_char c)


let loadGlyph f g=
  match f with
      CFF x->CFFGlyph (CFF.loadGlyph x g)
    | Opentype x->OpentypeGlyph (Opentype.loadGlyph x g)

let cardinal f=
  match f with
      CFF x->CFF.cardinal x
    | Opentype x->Opentype.cardinal x

let outlines gl=
  match gl with
      CFFGlyph x->CFF.outlines x
    | OpentypeGlyph x->Opentype.outlines x

let glyphFont gl=
  match gl with
      CFFGlyph x->CFF (CFF.glyphFont x)
    | OpentypeGlyph x->Opentype (Opentype.glyphFont x)

let glyphContents gl=
  match gl with
      CFFGlyph x->CFF.glyphContents x
    | OpentypeGlyph x->Opentype.glyphContents x


let glyphNumber gl=
  match gl with
      CFFGlyph x->CFF.glyphNumber x
    | OpentypeGlyph x->Opentype.glyphNumber x

let glyphWidth gl=
  match gl with
      CFFGlyph x->CFF.glyphWidth x
    | OpentypeGlyph x->Opentype.glyphWidth x

let glyph_y0 gl=
  match gl with
      CFFGlyph x->CFF.glyph_y0 x
    | OpentypeGlyph x->Opentype.glyph_y0 x
let glyph_y1 gl=
  match gl with
      CFFGlyph x->CFF.glyph_y1 x
    | OpentypeGlyph x->Opentype.glyph_y1 x

let select_features a b=match a with
    CFF x->CFF.select_features x b
  | Opentype x->Opentype.select_features x b

let fontFeatures a=match a with
    CFF x->CFF.font_features x
  | Opentype x->Opentype.font_features x


let positioning f glyphs=
  match f with
      CFF x->CFF.positioning x glyphs
    | Opentype x->Opentype.positioning x glyphs
