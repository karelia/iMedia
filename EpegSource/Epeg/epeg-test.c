#include <Epeg.h>

int main(int argc, char **argv)
{
        Epeg_Image * image;
        int w, h;

        if ( argc < 2 ) 
        {
                printf("Usage: %s input.jpg output.jpgn", argv[0]);
                return(1);
        }

        image = epeg_file_open(argv[1]);

        epeg_size_get(image, "w, "h);
        printf("%s -  Width: %d, Height: %dn", argv[1], w, h);
        printf("  Comment: %s", epeg_comment_get(image) );

        epeg_decode_size_set(image, 128, 96);
        epeg_file_output_set(image, argv[2]);
        epeg_encode(image);
        epeg_close(image);

        printf("... Done.n");
        return(0);
}

This code can be compiled in the following manner: gcc `epeg-config --libs --cflags` epeg-test.c -o epeg-test



master_sites sourceforge:enlightenment
checksums	md5 9b68516f27e8c0386d03168444a4f5de
depends_lib lib:libjpeg:jpeg 
configure.args	--mandir=${prefix}/share/man 
configure.env CPPFLAGS="-L${prefix}/lib -I${prefix}/include" CFLAGS="-no-cpp-precomp -L${prefix}/lib"


