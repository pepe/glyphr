require 'oily_png/canvas'
require 'ft2'

module Glyphr
  class Renderer
    attr_accessor :font, :size, :image_width, :image_height
    attr_reader :face, :image, :glyphs, :glyph_codes

    POINT_FRACTION = 26.6
    ONE64POINT = 64
    RESOLUTION = 72
    LEFT_MARGIN = 10

    def initialize(font = nil, size = 36)
      @font = font
      @size = size
      if font
        setup_ft
      end
    end

    def render(*composition)
      return false if not image_width or not composition

      glyphs_from composition

      render_glyphs

      reset_image

      compose_to_image

#      composition.each do |glyph_code|
#        face.load_glyph(glyph_code, FT2::Load::NO_HINTING)
#        glyph = face.glyph.render(FT2::RenderMode::NORMAL)
#        bitmap = glyph.bitmap
#        if x + bitmap.width + glyph.bitmap_left < image_width
#          if bitmap.width > 0
#            image_compose x, glyph, bitmap
#          end
#          x = x + glyph.h_advance
#        else
#          break
#        end
#      end

      return true
    end

    def reset_image
      @image = OilyPNG::Canvas.new(image_width, image_height, ChunkyPNG::Color::WHITE)
    end

    def image
      return @image.to_image if @image
    end

    def glyphs_from(composition)
      @glyph_codes = []
      if composition.size == 1 && composition.first.is_a?(String)
        composition.first.each_codepoint do |c|
          @glyph_codes << face.char_index(c)
        end
      else
        @glyph_codes = composition
      end
    end

    private
    # sets up all attributes of freetype
    def setup_ft
      unless face
        @face = FT2::Face.load(@font)
        face.select_charmap(FT2::Encoding::UNICODE)
        face.set_char_size size * ONE64POINT, size * ONE64POINT, RESOLUTION, RESOLUTION
      end
    end

    def render_glyphs
      @glyphs = []
      self.image_height = 0
      glyph_codes.each do |code|
        face.load_glyph(code, FT2::Load::NO_HINTING)
        glyph = face.glyph.render(FT2::RenderMode::NORMAL)
        y_off = ((size * ONE64POINT) / RESOLUTION - glyph.bitmap_top).to_i
        @glyphs << {
          :pixels => glyph.bitmap.buffer.bytes.to_a,
          :y_offset => y_off,
          :left => glyph.bitmap_left.to_i,
          :rows => glyph.bitmap.rows,
          :width => glyph.bitmap.width,
          :h_advance => glyph.h_advance
        }
        if (height = y_off + glyph.bitmap.rows) > image_height
          self.image_height = height
        end
      end
    end

    def compose_to_image
      x = LEFT_MARGIN
      @glyphs.each do |glyph|
        if x + glyph[:width] + glyph[:left] < image_width
          if glyph[:width] > 0
            glyph_image = OilyPNG::Canvas.new(glyph[:width],
                                              glyph[:rows],
                                              glyph[:pixels])
            @image.compose!(glyph_image, x + glyph[:left], glyph[:y_offset])
          end
          x = (x + glyph[:h_advance]).to_i
        else
          break
        end
      end
    end
  end
end
