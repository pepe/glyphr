require 'oily_png/canvas'
require 'ft2'

module Glyphr
  class Renderer
    attr_accessor :font, :size, :image_width
    attr_reader :face, :image, :hinting

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
      reset_image
      x = LEFT_MARGIN
      if composition.size == 1 && composition.first.is_a?(String)
        composition = glyphs_array_from(composition.first)
      end

      composition.each do |glyph_code|
        face.load_glyph(glyph_code, FT2::Load::NO_HINTING)
        glyph = face.glyph.render(FT2::RenderMode::NORMAL)
        bitmap = glyph.bitmap
        if x + bitmap.width + glyph.bitmap_left < image_width
          if bitmap.width > 0
            image_compose x, glyph, bitmap
          end
          x = x + glyph.h_advance
        else
          break
        end
      end

      return true
    end

    def reset_image
      @image = OilyPNG::Canvas.new(image_width, image_height, ChunkyPNG::Color::WHITE)
    end

    def image
      return @image.to_image if @image
    end

    #TODO move to its own class for font info
    def glyphs_array_from(text)
      arr = []
      text.each_codepoint do |c|
        arr << face.char_index(c)
      end
      return arr
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

    def image_compose(x, glyph, bitmap)
      glyph_image = OilyPNG::Canvas.new(bitmap.width, bitmap.rows, bitmap.buffer.bytes.to_a)
      y_off = (size - glyph.bitmap_top) - 1
      x_off = (x + glyph.bitmap_left).to_i
      @image.compose!(glyph_image, x_off, y_off)
    end

    def image_height
      @face_height ||= ((((face.ascender + face.descender.abs)/face.units_per_em.to_f) * size) * 1.1).round
    end
  end
end
