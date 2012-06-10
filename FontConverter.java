import java.awt.image.*;
import java.io.*;
import java.util.*;

import javax.imageio.*;

public class FontConverter {
	static String hex(long i) {
		String result = Long.toString(i, 16);
		while (result.length() < 8) result = "0" + result;
		return "0x" + result;
	}
	
	public static void main(String args[]) throws Exception {
		// open image
		BufferedImage image = ImageIO.read(new File("font.png"));
		int w = image.getWidth(null);
		int h = image.getHeight(null);
		int bits[] = new int[w * h];
		PixelGrabber pg = new PixelGrabber(image, 0, 0, w, h, bits, 0, w);
		pg.setColorModel(ColorModel.getRGBdefault());
		pg.grabPixels();

		// print pixels
		int c = 0;
		for (int y = 0; y < 3; y++) {
			for (int x = 0; x < 13; x++) {
				long line = 0;
				for (int yc = 0; yc < 16; yc++) {
					for (int xc = 0; xc < 16; xc++) {
						if ((bits[x * 16 + y * w * 16 + xc + yc * w] & 0xff) != 0) {
							line |= (long) (1 << (15 - xc)) & 0xffffffff;
						}
					}
					if ((yc & 1) == 1) {
						System.out.print(hex(line) + ", ");
						if (c++ == 7) {
							System.out.println("");
							c = 0;
						}
						line = 0;
					} else {
						line <<= 16;
					}
				}
			}
		}
	}
}
