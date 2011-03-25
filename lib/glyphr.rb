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
      @y_min = 0
      @image_height = 0
      glyph_codes.each do |code|
        face.load_glyph(code, FT2::Load::NO_HINTING)
        glyph = face.glyph.render(FT2::RenderMode::NORMAL)
        x_min, y_min, x_max, y_max = face.glyph.glyph.cbox FT2::GlyphBBox::PIXELS
        @glyphs << {
          :bitmap_top => glyph.bitmap_top,
          :pixels => glyph.bitmap.buffer.bytes.to_a,
          :left => glyph.bitmap_left.to_i,
          :rows => glyph.bitmap.rows,
          :width => glyph.bitmap.width,
          :h_advance => glyph.h_advance
        }
        if (height = (y_max - y_min) + 1) > @image_height
          @image_height = height
        end
        @y_min = y_min if y_min < @y_min
      end
      @image_height -= @y_min
    end

    def compose_to_image
      x = LEFT_MARGIN
      @glyphs.each do |glyph|
        if x + glyph[:width] + glyph[:left] < image_width
          if glyph[:width] > 0
            glyph_image = OilyPNG::Canvas.new(glyph[:width],
                                              glyph[:rows],
                                              glyph[:pixels])
            @image.compose!(glyph_image, x + glyph[:left], (image_height - glyph[:bitmap_top] + @y_min))
          end
          x = (x + glyph[:h_advance]).to_i
        else
          break
        end
      end
    end
  end
end

