;это комнада для вывода матрциы в gdb 
;x/25gd &matrix ($rdi)


; при вызове процедуры важно учитывать слудеющее:
; 1. регистры rdi, rsi, rdx, rcx, r8, r9 можно просто как то изменить
; в вызывающей процедуре или глобальной метке и потом они передадутся в вызываемую процедуру
; в том состоянии в котором мы их установили в вызывающей процедуре и т п
; 2. вызываемая процедура может юзать регситры r12, r13, r14, r15, rbx, rbp но тогда надо
; учитывать что если она их юзает то и вызываемая программа будет использовать в последствии
; уже поюзанные (испорченные) эти регистры
; поэтому эта проблема решается так:
; вызываемая процедура должны сначала положить на стек регситры из этих шести
; которые будет исполбзовать (можно когда угодно но перед использованием по уже оговоренным причинам)
; то есть надо сделать push register а потмо после всех возможных махинаций с данными регаистрами должна эти
; регистры "восстановить" то есть сделать pop register
; 3. при выходе из процедуры мы должны сделать 
; mov rsp, rbp 
; pop rbp
; sub rsp, ... (если это нужно для того чтобы стек был выровнен по 16 байт)
; 4. если вызывающая программа пользуется регистрами которые вызываемая программа сохранять не должна
; то вызывающая программа сохраняет регистры на стеке или в стековом кадре а после возврата из процедуру
; восстанавливает эти регистры
; 5. результат возвращается в регистре rax
; ну там еще всякого можно понаписать но нет смысла для этой лабы

;директива препроцессора нужна крч чтобы через командную строку (или это все дело
;можно замасикровать под другой флаг при помощи Makefile как сделал я с флагом
;ORDER=DESC) говорить программе о том в каком порядке надо делать сортировку
%ifdef ORDER_DESC
    %define SORT_ORDER_JMP jg ; по убыванию matrix[j][current_column] > key
%else
    %define SORT_ORDER_JMP jl ; по возрастанию (дефолт варик) matrix[j][current_column] < key
%endif

section .data
    ; объявление матрицы целых 64-битных чисел
    ; далее буду передавать ее только в качестве адерса на начало
    ; массива длиной cnt_of_clmns * cnt_of_rows
    ; так то опредееление этого массивчика как проямоугольной матриы чисто 
    ; формальное, ведь это просто массив (хотя может можно было бы сделать
    ; структурку в которой все необходимое хранилось бы все необходимое и был бы
    ; как в С указатель на указатель)
    matrix:
        dq 5, 9, 5, 9, 5
        dq 4, 8, 4, 8, 4
        dq 3, 7, 3, 7, 3

section .rodata
    clmn equ 3 ; cnt_of_clmns
    row equ 5 ; cnt_of_rows

section .text
global _start


;АЛГОРИТМ СОРТИРОВКИ ВСТАВКАМИ (INSERTION SORT)
;это типа реализация на плюсах или с как кому удобно и так все понятно
;халява короче
;
;   for (int i = 1; i < n; ++i) {
;       int key = arr[i];
;       int j = i - 1;
        ; Move elements of arr[0..i-1], that are
        ;  greater than key, to one position ahead
        ;  of their current position 
;        while (j >= 0 && arr[j] > key) {
;           arr[j + 1] = arr[j];
;           j = j - 1;
;       }
;       arr[j + 1] = key;
;   }

insertion_sort:
 
   push rbp
   mov rbp, rsp

   push rbx
   push r12
   push r13
   push r14
   push r15

   mov r12, rdi ;r12 = address of matrix (=rdi)
   mov r13, rsi ;r13 = cnt_of_rows
   mov r14, rdx ;r14 = cnt_of_clmns
   mov r15, rcx ;r15 = index of current column

   mov r8, 1 ;r8 = start of column's array. r8 = i = 1


;сейчас при индексации надо будет учитывать как в памяти лежат элементы
;если мы хотим проходится по элемнетам опеределенного столбца, то нам
;надо понимать что он находится по адресу [r12 + (i * cnt_ofclmns + current_index_of_column) * 8]
;где i - переменная итерирования и увеличивается она короче на 1 каждый раз от 1 до количества строк
;в матрице (cnt_of_rows) при этом r12 - адрес начала матрицы который мы передали в использование выше
;по стеку функций (а именно в _start) все остальное и так понятно  но я поясню все же себе ну будущее
;при итерировании по элементам столбца мы должны еще учитывать что надо как бы перепрыгнуть все остальные
;элементы матрицы которые имеются как бы в той же строке но все еще не нужный столбец ну и короче да
;поэтому каждый раз юзаем cnt_of_clmns


.for_loop: ;int i = 1; i < cnt_of_rows; i ++
   cmp r8, r13
   jge .for_loop_done 
   ; эта метка на самом то деле соответствует
   ; функции сортировки для столбца
   ; так что там же надо будет сделать еще операции которые нужны
   ; при окончании функции
   
   mov rax, r8
   imul rax, r14
   add rax, r15
   mov rbx, [r12 + rax * 8] ;rbx = key = matrix [i][current_column]
   ;в соотвествии с изложенным выше алгоритмом

   mov r9, r8 ; j = i
   dec r9 ;j = i - 1 в результате этих двух строчек я в шоке

.while_loop: ;while (j >= 0 && matrix[j][current_column] > key) (key = rbx) (далее будем декрменетить j)
   
   ; проверка  для цикла j >= 0
   cmp r9, 0
   jl .while_loop_done

   ; проверка matrix[j][current_column] > key
   mov rax, r9
   imul rax, r14
   add rax, r15
   mov r10, [r12 + rax * 8] ; r10 = matrix [j][current_column]

   ; проверка того что matrix [j][current_column] >(default)/<(-DORDER_DESC) key (rbx = key, r10 = matrix[j][current_column])
   cmp r10, rbx
   SORT_ORDER_JMP .while_loop_done
   
   mov rcx, r9 ; rcx = j
   inc rcx ; rcx = j + 1
   imul rcx, r14
   add rcx, r15 
   mov [r12 + rcx * 8], r10 ; matrix [j + 1][current_column] = matrix [j][current_column]

   dec r9 ; j = j - 1
   jmp .while_loop

.while_loop_done:
   mov rax, r9 ; rax = r9 = j
   inc rax ; rax = j + 1
   imul rax, r14
   add rax, r15
   mov [r12 + rax * 8], rbx ; matrix[j + 1][current_column] = key

   inc r8 ; r8 (= i) ++
   jmp .for_loop

.for_loop_done:
   pop r15
   pop r14
   pop r13
   pop r12
   pop rbx

   mov rsp, rbp
   pop rbp

   ret


; функция обработки всей матрицы
matrix_proccess:
   push rbp
   mov rbp, rsp

   push rbx
   push r12
   push r13
   push r14
   push r15

   mov r12, rdi ;r12 = matrix
   mov r13, rsi ;r13 = cnt_of_rows
   mov r14, rdx ;r14 = cnt_of_clmns

    ; matrix is empty?
   cmp r13, 0
   jle .done

   ;matrix is easy sorted?
   cmp r14, 0
   je .done

   xor r15, r15

; цикл по всем столбцам которые мы имеем в матрице с инлексацией от 0 до cnt_of_clmns - 1 включительно
.clmn_loop:
   cmp r15, r14
   jge .done

   mov rdi, r12
   mov rsi, r13
   mov rdx, r14
   mov rcx, r15

   call insertion_sort

   inc r15
   jmp .clmn_loop

   
.done:

   pop r15
   pop r14
   pop r13
   pop r12
   pop rbx
   mov rsp, rbp
   pop rbp

   ret

_start:
    lea rdi, [matrix] ; mov rdi, matrix
    mov rsi, row
    mov rdx, clmn

    call matrix_proccess

    mov rax, 60
    xor rdi, rdi
    syscall
