require "sdl"

module Cryngine
  module Display
    class DitherTool
      getter wand : Pointer(LibMagick::MagickWand)
      getter dither_wand : Pointer(LibMagick::MagickWand)
      class_property dither_colors_image : String = "lib/cryngine/assets/OC.png"
      @wand = uninitialized Pointer(LibMagick::MagickWand)
      @dither_wand = uninitialized Pointer(LibMagick::MagickWand)
      LibMagick.magickWandGenesis

      def initialize(@wand = LibMagick.newMagickWand)
        @dither_wand = LibMagick.newMagickWand
        LibMagick.magickReadImage @dither_wand, self.class.dither_colors_image
      end

      def load_image(pixels : Bytes)
        if LibMagick.magickReadImageBlob @wand, pixels, pixels.size
        else
          puts "Read image error"
        end
      end

      def save(path)
        LibMagick.magickWriteImage @wand, path
      end

      def floyd_steinberg
        LibMagick.magickRemapImage @wand, @dither_wand, LibMagick::DitherMethod::FloydSteinbergDitherMethod
      end

      def scale(scale : Float64, width : Int32, height : Int32)
        LibMagick.magickResizeImage @wand, (width * scale).to_i, (height * scale).to_i, LibMagick::FilterType::BoxFilter
      end

      def cleanup
        LibMagick.destroyMagickWand @wand        # lib deinit
        LibMagick.destroyMagickWand @dither_wand # lib deinit
      end

      def self.cleanup
        # LibMagick.destroyMagickWand @dither_wand # lib deinit
        LibMagick.magickWandTerminus
      end

      def as_bytes
        LibMagick.magickSetImageFormat @wand, "BMP"
        buffer = LibMagick.magickGetImageBlob @wand, out length
        # puts "#{buffer.class}, #{length}"
        Bytes.new(buffer, length)
      end
    end
  end
end
