# image_crop_offset.ps1
# Find the horizontal crop offset between two versions of the SAME artwork,
# assuming a 1:1 (no scaling) relationship: target == source[u .. u+CropWidth].
#
# Why not mean-absolute-difference: two assets from different sources usually
# differ in overall brightness/tint, which drags MAD toward the wrong answer.
# Here we high-pass both images (subtract a box blur) and use ZNCC instead, so
# only structure matters. A trustworthy match is a SHARP peak with ZNCC > 0.9.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\image_crop_offset.ps1 `
#       -Source assets\image\garden\Background_Greenhouse_New.png `
#       -Target assets\image\garden\Background_Greenhouse.jpg
#
# Pure ASCII on purpose (PS 5.1 parses BOM-less files as ANSI).

param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target,
    [int]$CropWidth = 800,
    [int]$GridW = 160,
    [int]$GridH = 120,
    [int]$BlurRadius = 5
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class CropAlign
{
    static int gW, gH, gR;

    static double[] SampleCrop(Image src, float dx, int cropW)
    {
        var small = new Bitmap(gW, gH);
        using (var g = Graphics.FromImage(small))
        {
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.Bilinear;
            g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
            g.DrawImage(src, new RectangleF(0f, 0f, (float)gW, (float)gH),
                             new RectangleF(dx, 0f, (float)cropW, (float)src.Height), GraphicsUnit.Pixel);
        }
        var d = small.LockBits(new Rectangle(0, 0, gW, gH), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
        byte[] buf = new byte[d.Stride * gH];
        Marshal.Copy(d.Scan0, buf, 0, buf.Length);
        small.UnlockBits(d);
        double[] luma = new double[gW * gH];
        for (int y = 0; y < gH; y++)
        {
            int row = y * d.Stride;
            for (int x = 0; x < gW; x++)
            {
                int o = row + x * 3;
                luma[y * gW + x] = 0.299 * buf[o + 2] + 0.587 * buf[o + 1] + 0.114 * buf[o];
            }
        }
        small.Dispose();
        return HighPass(luma);
    }

    static double[] HighPass(double[] g)
    {
        double[] tmp = new double[gW * gH];
        double[] blur = new double[gW * gH];
        int r = gR;
        for (int y = 0; y < gH; y++)
            for (int x = 0; x < gW; x++)
            {
                double s = 0; int c = 0;
                for (int k = -r; k <= r; k++) { int xx = x + k; if (xx < 0 || xx >= gW) continue; s += g[y * gW + xx]; c++; }
                tmp[y * gW + x] = s / c;
            }
        for (int x = 0; x < gW; x++)
            for (int y = 0; y < gH; y++)
            {
                double s = 0; int c = 0;
                for (int k = -r; k <= r; k++) { int yy = y + k; if (yy < 0 || yy >= gH) continue; s += tmp[yy * gW + x]; c++; }
                blur[y * gW + x] = s / c;
            }
        double[] res = new double[gW * gH];
        for (int i = 0; i < gW * gH; i++)
        {
            double v = g[i] - blur[i];
            if (v > 60) v = 60; else if (v < -60) v = -60;
            res[i] = v;
        }
        return res;
    }

    static double Zncc(double[] a, double[] b)
    {
        int n = a.Length;
        double ma = 0, mb = 0;
        for (int i = 0; i < n; i++) { ma += a[i]; mb += b[i]; }
        ma /= n; mb /= n;
        double sa = 0, sb = 0, sab = 0;
        for (int i = 0; i < n; i++)
        {
            double da = a[i] - ma, db = b[i] - mb;
            sa += da * da; sb += db * db; sab += da * db;
        }
        return sab / Math.Sqrt(sa * sb + 1e-9);
    }

    public static string Run(string pathSource, string pathTarget, int cropW, int gw, int gh, int r)
    {
        gW = gw; gH = gh; gR = r;
        var A = Image.FromFile(pathSource);
        var B = Image.FromFile(pathTarget);
        double[] target = SampleCrop(B, 0f, cropW);

        double best = -2; int bestDx = 0;
        int maxDx = A.Width - cropW;
        for (int dx = 0; dx <= maxDx; dx++)
        {
            double s = Zncc(SampleCrop(A, (float)dx, cropW), target);
            if (s > best) { best = s; bestDx = dx; }
        }
        string curve = "";
        for (int dx = Math.Max(0, bestDx - 12); dx <= Math.Min(maxDx, bestDx + 12); dx += 2)
        {
            double s = Zncc(SampleCrop(A, (float)dx, cropW), target);
            curve += (" " + dx + ":" + s.ToString("F3"));
        }
        A.Dispose(); B.Dispose();
        return "bestDx=" + bestDx + "  zncc=" + best.ToString("F4") + "\n  curve:" + curve;
    }
}
'@ -ReferencedAssemblies System.Drawing

Write-Output ("source: " + $Source)
Write-Output ("target: " + $Target)
Write-Output ([CropAlign]::Run($Source, $Target, $CropWidth, $GridW, $GridH, $BlurRadius))
Write-Output "A sharp peak above ~0.9 means: target == source[dx .. dx+width], i.e. subtract dx from source coordinates."
