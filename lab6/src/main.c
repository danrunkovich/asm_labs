#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "process/proc.h"

#define STB_IMAGE_IMPLEMENTATION
#include "../extern/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "../extern/stb_image_write.h"



#ifndef OPT_FLAGS
    #define OPT_FLAGS "unknown"
#endif

#if defined (USE_ASM_S)
    #define PROCESS_FUNC process_image_asm_scalar
    const char* impl_name = "ASM x86-64 scalar";
#elif defined (USE_ASM_V)
    #define PROCESS_FUNC process_image_asm_vector
    const char* impl_name = "ASM x86-64 vector";
#else
    #define PROCESS_FUNC proess_image_c
    const char* impl_name = "C";
#endif


int main (int argc, char** argv) {
    if (argc < 3) {
        printf ("Ошибка : мало параметров\n");
        return 1;
    }

    const char* input_path = argv[1];
    const char* output_path = argv[2];


    printf ("Загрузка изображения\n");
    int width = 0, height = 0, channels = 0;
    unsigned char* img_data = stbi_load(input_path, &width, &height, &channels, 0); // передаем ластовым аргументом 0, чтобы
    // не менять никак изображение и получить нужное крооличесвто каналов через channels

    if (img_data == NULL) {
        fprintf (stderr, "Ошибка : не удалось загрузить изображение -> %s\n", input_path);
        return 1;
    }

    printf ("\tИзображение -> %d * %d\n\tКаналов -> %d", width, height, channels);
    printf ("\n--------------------------\nИспользуемая реалиазция -> %s\n", impl_name);

    unsigned char* gray_src = (unsigned char*) malloc (width * height * sizeof(char));

    if (!gray_src) {
        fprintf (stderr, "Ошибка : не получилось выделить память для grey_src\n");
        stbi_image_free(img_data);
        return 1;
    }


    for (int i = 0; i < width * height; i ++) {
        unsigned char* p = img_data + i * channels;
        if (channels >= 3) {
            gray_src[i] = (unsigned char) ((77 * p[0] + 150 * p[1] + 29 * p[2]) >> 8); // перевод с одноканальную data для image
            // которая будет обрабатываться нашей программой
            // при этом данные кэффы взяты как по мне фиг знает откуда (по стандарту ВТ.601 они взяты
            // согласно тому как наш глаз чувствителен к конкретной компоненте)
            // для тех кто булет читать мой код напоминаю, что
            //      RED-компонента это p[0]
            //      GREEN-компонента это p[1]
            //      BLUE-компонента это p[2]
            // при чем важно понимать что при данном переводе информации о картинке мы работаем именно
            // с его трехканальным представлением (то есть если каналов тупа больше то они нам не интересны)
            // если же при этом каналов меньше трех
            // то мы заходим в нижеуказанный else в теле данного for-цикла
            // при этом это все важно понимать так как оператор Sobel filtr абсолютно равнодушен ко всем альфа-каналам
            // сдвиг на один байтик (>>8) это чисто выпендреж для помеещения в однобацтовый char той информации которая нам нужна
            // так то можно и просто поделить на 2^8 и никто никого за это не накажет
            // а еще это быстро однако на результаты таймирования это естественно никак не влияет
            // так как замеряется именно программа обработки изображения а не все остальное
        }
        else gray_src[i] = p[0];
    }

    unsigned char * gray_dst = (unsigned char*) malloc (height * width);
    if (!gray_dst) {
        fprintf (stderr, "Ошибка : не хватило памяти для gray_dst\n");
        free (gray_src);
        stbi_image_free(img_data);
        return 1;
    }

    struct timespec start, end;
    clock_gettime (CLOCK_MONOTONIC, &start);

    PROCESS_FUNC (gray_src, gray_dst, width, height);

    clock_gettime (CLOCK_MONOTONIC, &end);

    double elapsed = (end.tv_nsec - start.tv_nsec) / 1000;

    printf ("======Время обработки -> %.15lf ms======\n", elapsed);

    printf ("Сохранение изображения -> %s\n", output_path);

    FILE* f = fopen("timing/results_timing.txt", "a");
    if (f) {
        // Если файл пустой, можно записать заголовок
        fseek(f, 0, SEEK_END);
        if (ftell(f) == 0) {
            fprintf(f, "| Реализация | Оптимизация | Время (милисек) |\n");
            fprintf(f, "|------------|-------------|-----------------|\n");
        }
        fprintf(f, "| %-10s | %-11s | %-15.6f |\n", impl_name, OPT_FLAGS, elapsed); // (-11) это выравнивание по левому краю
        // + 11 минимальное количесвто символов (если <11 то будет дополняться пробелами)
        fclose(f);
    }
    if (!stbi_write_jpg(output_path, width, height, channels, img_data, 1500)) {
        fprintf (stderr, "Ошибка : не удалось сохранить изображение -> %s\n", output_path);
        stbi_image_free(img_data);
        return 1;
    }

    stbi_image_free(img_data);
    return 0;
}
