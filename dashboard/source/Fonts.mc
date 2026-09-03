import Toybox.Graphics;
import Toybox.Lang;

//! Font selection.
//!
//! The face is laid out in fractions of the screen, but the built-in system
//! fonts come in a handful of fixed sizes that differ per device. Rather than
//! hard coding a font per screen size, we measure the candidates once at layout
//! time and keep the largest one that still fits its row.
module Fonts {
  //! Candidates for the big clock, largest first.
  function time() as Array {
    return [
      Graphics.FONT_NUMBER_THAI_HOT,
      Graphics.FONT_NUMBER_HOT,
      Graphics.FONT_NUMBER_MEDIUM,
      Graphics.FONT_NUMBER_MILD,
      Graphics.FONT_LARGE,
    ];
  }

  //! Candidates for the text rows, largest first.
  function row() as Array {
    return [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
  }

  //! Largest candidate whose bounding box for `sample` stays inside
  //! `maxWidth` x `maxHeight`. Falls back to the smallest candidate.
  function fit(dc as Graphics.Dc, candidates as Array, sample as String, maxWidth as Numeric, maxHeight as Numeric) {
    for (var i = 0; i < candidates.size(); i++) {
      var dimensions = dc.getTextDimensions(sample, candidates[i]);
      if (dimensions[0] <= maxWidth && dimensions[1] <= maxHeight) {
        return candidates[i];
      }
    }
    return candidates[candidates.size() - 1];
  }
}
