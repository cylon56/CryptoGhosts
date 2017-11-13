from PIL import Image
import glob

i=0
# Hold actual image objects
sheets = []
mouths = []
eyes = []
hats = [Image.new("RGBA", (32,32), 0)]
ghosts = []

# Hold just the string file names
sheet_names = [s for s in glob.glob("./Pieces/b_*.png")]
mouth_names = [m for m in glob.glob("./Pieces/m_*.png")]
eye_names = [e for e in glob.glob("./Pieces/e*.png")]
hat_names = [h for h in glob.glob("./Pieces/hat_*.png")]

for s in sheet_names:
    sheets.append(Image.open(s).convert("RGBA"))

for m in mouth_names:
    mouths.append(Image.open(m).convert("RGBA"))

for e in eye_names:
    eyes.append(Image.open(e).convert("RGBA"))

for h in hat_names:
    hats.append(Image.open(h).convert("RGBA"))

for s in sheets:
    for m in mouths:
        for e in eyes:
            for h in hats:
                ghosts.append(Image.new("RGBA", (32,32), 0))
                ghosts[i].paste(s, (0,0), s)
                ghosts[i].paste(e, (0, 0), e)
                ghosts[i].paste(m, (0, 0), m)
                ghosts[i].paste(h, (0,0), h)
                filename = "./Ghosts/new" + i.__str__() + ".png"
                ghosts[i].save(filename, "PNG")
                i+=1
