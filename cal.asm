; ��A��������+��
; ��B��������-��
; ��C��������*�� 
; ��D�����������š� 
; ��E��������=�� 
; ��F��������ʼ���㣨�����������㣩����Ļ��ʾ��0����
;
; ����Ҫ�� 
;     �� ������������ݣ�С����λ����������ܸ�����ʾ�� 
;     �� ����+������-������*�������š�ʱ����ǰ��ʾ���ݲ��䡣 
;     �� ����������ʱ������ܸ�����ʾ�� 
;     �� ����E��ʱ����ʾ���ս�����ݡ���������Ϊ�����������1����ɫ��������ܣ���������1���
;     ����Ӳ��ʵ�֣���˸����������Ϊż���������2����ɫ��������ܣ���������2������Ӳ��ʵ�֣���
;     ˸�� 
;     �� ����F����������ĸ�����������ұߣ���Ӧ��λ������һ����ʾ��0����������������ʾ���ݡ�
;     ͬʱϨ������ķ�������ܣ��ȴ���һ������Ŀ�ʼ�� 
;     �� ��Ҫ������������ȼ����⡣ 
;     �� ����ֻ�������������㣬�����Ǹ�����ʵ�����㡣���ſ��Բ�����Ƕ���������������ʵ����ʽ
;     �д��ڶ���ƽ�����ŵļ��㡣
;
; ���˵���� 
;     ��������ʱ����������ʾ��Χ����Ӧ�������֡��ڼ�����������ʾ��Χʱ������ʾ��F����


code    segment
        assume cs:code


    ; �жϿ����� 8259
    ; 8259ֻ��������8253�ļ�ʱ�ж�
    port59_0    equ 0ffe4h
    port59_1    equ 0ffe5h
    icw1        equ 13H         ; ���ش���
    icw2        equ 08h         ; �ж����ͺ� 08H 09H ...
    icw4        equ 09h         ; ȫǶ�ף��ǻ��壬���Զ�EOI��8086/88ģʽ
    ocw1open    equ 07fh        ; IRQ7�����ͺ�Ϊ0fh��������ַƫ�Ƶ�ַ3ch���ε�ַ0���ο�ʾ����13��

    ; ���нӿ�оƬ 8255
    ; 8255��led�����led״̬
    port55_a    equ 0ffd8H
    port55_ctrl equ 0ffdBH

    ; ������ʱоƬ 8253
    port53_0    equ 0ffe0H
    port53_ctrl equ 0ffe3H      ; ���ƿ�
    count_1sec  equ 19200       ; 1s��������
    count_2sec  equ 38400       ; 2s��������


    ledbuf                  db 6 dup(?)
    led_count               db 0
    previous_key            db 20h
    current_key             db 20h
    has_previous_bracket    db 0
    same_as_pre             db 0

    operator_stack          db '#', 100 dup(?)      ; si
    operand_stack           dw 0ffffh, 100 dup(?)   ; di

    priority                db 0    ; 0 ջ��<��һ��; 1 =; 2 >
    is_save_num             db 0    ;������һ�������ʱ��current_num�Ƿ��Ѿ�����
    current_num             dw 0
    result                  dw 0
    led_overflow            db 0
    whole_error             db 0
    ;   # ( + - *
    ; # f f f f f
    ; ( f f f f f
    ; + 2 2 1 1 0
    ; - 2 2 1 1 0
    ; * 2 2 2 2 1
    priority_table  db  0ffh, 0ffh, 0ffh, 0ffh, 0ffh
                    db  0ffh, 0ffh, 0ffh, 0ffh, 0ffh
                    db  2, 2, 1, 1, 0
                    db  2, 2, 1, 1, 0
                    db  2, 2, 2, 2, 1


    OUTSEG  equ  0ffdch             ;�ο��ƿ�
    OUTBIT  equ  0ffddh             ;λ���ƿ�/��ɨ��
    IN_KEY  equ  0ffdeh             ;���̶����


org  1000h
start:
    cli
    call init_all
main:
    sti
    ;call get_key
    ;cmp current_key, 20h
    ;je handle
    ;and  al,0fh
    ;handle:
    ;call handle_key
    call set_led_num
    call disp
    jmp main
; end



init_all proc
        call init8259
        call init8255
        call init8253
        call clean_all
        ret
init_all endp


init8259 proc
        push ax
        push dx
        mov dx, port59_0
        mov al, icw1
        out dx, al
        mov dx, port59_1
        mov al, icw2
        mov dx, port59_1
        out dx, al
        mov al, icw4
        out dx, al
        mov al, ocw1open
        out dx, al
        pop dx
        pop ax
        ret
init8259 endp


init8255 proc
        push ax
        push dx
        mov dx, port55_ctrl
        mov al, 88H
        out dx, al
        ;mov al, lightOff    ; TODO
        mov dx, port55_a
        out dx, al
        pop dx
        pop ax
        ret
init8255 endp


init8253 proc
        push dx
        push ax
        mov dx, port53_ctrl
        mov al, 30H            ; ������0���ȵ�8λ���ٸ�8λ����ʽ0�������Ƽ���
        out dx, al
        pop ax
        pop dx
        ret
init8253 endp


init_stack proc
        mov si, 0
        mov di, 0
        ret
init_stack endp


clean_all proc
        call init_stack
        call clean_led
        mov previous_key, 20h
        mov current_key, 20h
        mov led_count, 0
        mov has_previous_bracket, 0
        mov same_as_pre, 0
        mov current_num, 0
        mov result, 0
        mov led_overflow, 0
        mov is_save_num, 0
        mov whole_error, 0
        ret
clean_all endp


clean_led proc
        mov  LedBuf+0,0ffh
        mov  LedBuf+1,0ffh
        mov  LedBuf+2,0ffh
        mov  LedBuf+3,0c0h
        mov  LedBuf+4,0ffh
        mov  LedBuf+5,0ffh
        ret
clean_led endp


get_key proc                    ;��ɨ�ӳ���
    ; store key in current_key
        push ax
        push bx
        push cx
        push dx

        mov al, current_key     ;��һ��ɨ��ķ���
        mov previous_key, al

        mov  al,0ffh            ;����ʾ��
        mov  dx,OUTSEG
        out  dx,al
        mov  bl,0
        mov  ah,0feh
        mov  cx,8
    key1:   
        mov  al,ah
        mov  dx,OUTBIT
        out  dx,al
        shl  al,1
        mov  ah,al
        nop
        nop
        nop
        nop
        nop
        nop
        mov  dx,IN_KEY
        in   al,dx
        not  al
        nop
        nop
        and  al,0fh
        jnz  key2
        inc  bl
        loop key1
    nkey:   
        mov  al,20h
        mov current_key, al
        pop dx
        pop cx
        pop bx
        pop ax
        ret
    key2:   
        test al,1
        je   key3
        mov  al,0
        jmp  key6
    key3:   
        test al,2
        je   key4
        mov  al,8
        jmp  key6
    key4:   
        test al,4
        je   key5
        mov  al,10h
        jmp  key6
    key5:   
        test al,8
        je   nkey
        mov  al,18h
    key6:   
        add  al,bl
        cmp  al,10h
        jnc  fkey
        mov  bx,offset KeyTable
        xlat
    fkey:   
        mov current_key, al
        pop dx
        pop cx
        pop bx
        pop ax
        ret
get_key endp


handle_key proc
        push ax
        call is_same_as_pre
        mov al, current_key
        cmp same_as_pre, 1
        jne handle_key_continue
        pop ax
        ret
    handle_key_continue:
        cmp al, 10
        jnb handle_key_a
        call handle_number
        pop ax
        ret
    handle_key_a:
        cmp al, 0ah
        jne handle_key_b
        call handle_a
        pop ax
        ret
    handle_key_b:
        cmp al, 0bh
        jne handle_key_c
        call handle_b
        pop ax
        ret
    handle_key_c:
        cmp al, 0ch
        jne handle_key_d
        call handle_c
        pop ax
        ret
    handle_key_d:
        cmp al, 0dh
        jne handle_key_e
        call handle_d
        pop ax
        ret
    handle_key_e:
        cmp al, 0eh
        jne handle_key_f
        call handle_e
        pop ax
        ret
    handle_key_f:
        cmp al, 0fh
        jne key_error
        call handle_f
        jmp handle_key_f_ret
        key_error:
        call handle_error
        handle_key_f_ret:
        pop ax
        ret
handle_key endp

is_same_as_pre proc
    ;��same_as_pre��ֵ
    push ax
    mov al, current_key
    cmp al, previous_key
    je is_same
    mov same_as_pre, 0
    jmp return
is_same: 
    mov same_as_pre, 1
return:    
    pop ax
    ret
is_same_as_pre endp


    display_num             dw 13

handle_number proc
    ; ��� led_count < 4
    ;   current_num = current_num * 10 + current_key
    ;   led_count += 1
    ; ����
    ;   call do_nothing
    ; ��������������ķ��ŵ�ʱ����Ҫ��led_count���
    push ax
    push bx
    push dx
    mov is_save_num, 0           ;�����µ�����ʱ�����óɵ�ǰ���ֻ�δ����
    cmp led_count, 4
    jae handle_number_ret        ; TODO euqal
    mov ax, current_num
    mov bx, 10
    mul bx
    mov bl, current_key
    mov bh, 0
    add ax, bx               
    mov current_num, ax          ;current_num = current_num * 10 + current_key
    inc led_count
    push ax
    mov ax, current_num
    mov display_num, ax
    pop ax
    handle_number_ret:
    pop dx
    pop bx
    pop ax
    ret
handle_number endp

handle_error proc
    ;����get_key�õ����ַ��������ֺͷ��ŵ����������current_key=20h
    cmp current_key, 20h
    je handle_error_ret
    ;TODO ;���������ķ���
    handle_error_ret:
    ret
handle_error endp

handle_a proc
    ;�����������a(�Ӻ�)�����
    cmp is_save_num, 0
    jne calculate_a
    mov is_save_num, 1
    inc di
    push ax
    mov ax, current_num
    mov operand_stack[di], ax           ;��current_num��ջ
    pop ax
    mov led_count, 0
    mov current_num, 0                    ;���������ʱ�������������������ǰ���������
    calculate_a:
    cmp whole_error, 1
    je a_ret                              ;��ǰ���ʽ���Ѿ���������ʱ������ʽ�Ӳ���Ҫ������
    call get_priority
    cmp priority, 0
    je push_a                             ;��ǰ�������ȼ�����ջ�����ţ�ֱ����ջ
    call cal_one_op                       ;�������һ��
    jmp calculate_a
    push_a:
    inc si
    push ax
    mov al, current_key
    mov operator_stack[si], al          ;����ǰ�������ջ
    pop ax
    a_ret:
    ret
handle_a endp

handle_b proc
    call handle_a
    ret
handle_b endp

handle_c proc
    call handle_a
    ret
handle_c endp

handle_d proc
    cmp has_previous_bracket, 0
    je no_previous
    mov has_previous_bracket, 0
    cal_between_bracket:
    cmp operator_stack[si], 0dh
    je is_left_bracket
    call cal_one_op
    jmp cal_between_bracket
    is_left_bracket:
    dec si
    jmp ret_d
    no_previous:
    mov has_previous_bracket, 1
    inc si
    push ax
    mov al, current_key
    mov operator_stack[si], al
    pop ax
    ret_d:
    ret
handle_d endp

handle_e proc
    push ax
    cal_e:
    cmp whole_error, 1
    je ret_e
    cmp operator_stack[si], '#'
    je ret_e
    call cal_one_op
    jmp cal_e
    ret_e:
    cmp whole_error, 1
    je show_error
    mov ax, operand_stack[di]
    mov display_num, ax
    call set_led_num
    show_error:
    ;TODO                                ;�����ʾ
    pop ax
    ret
handle_e endp

handle_f proc
    call init_all
    ret
handle_f endp


cal_one_op proc
        push ax
        push dx
        cmp si, 1
        jb cal_error
        cmp di, 4
        jb cal_error
        mov ax, operand_stack[di - 2]
        mov dl, operator_stack[si]

        cmp dl, 0ah                 ; +
        jne cal_not_plus
        add ax, operand_stack[di]
        jo cal_overflow             ; �ӷ����Ϊoverflow
        jmp cal_ret
    cal_not_plus:
        cmp dl, 0bh                 ; -
        jne cal_not_minus
        sub ax, operand_stack[di]
        js cal_overflow             ; �����ø�ҲΪoverflow
        jmp cal_ret
    cal_not_minus:
        cmp dl, 0ch                 ; *
        jne cal_error               ; ���� + - * Ϊerror
        mul operand_stack[di]
        cmp dx, 0
        jne cal_overflow            ; �˷����Ϊoverflow
        jmp cal_ret
    cal_error:
        mov whole_error, 1
        jmp cal_ret
    cal_overflow:
        mov led_overflow, 1
    cal_ret:
        sub di, 2
        dec si
        mov operand_stack[di], ax
        pop dx
        pop ax
        ret
cal_one_op endp


get_priority proc
    ; ջ����(����#��Ϊerror����Ϊhandle_key�߼�����������������Ϊ
        push ax
        push bx
        push dx
        mov al, operator_stack[si]
        mov dl, current_key
        cmp al, '#'
        je get_priority_err
        cmp al, 0dh
        je get_priority_err
        sub al, 0ah
        add al, 2
        sub dl, 0ah
        add dl, 2
        mov dh, 5           ; 5 x 5 �����ȱ�
        mul dh
        add al, dl
        mov ah, 0
        ; dec ax            ; ����Ҫ��1
        mov bx, ax
        mov dl, priority_table[bx]
        mov priority, dl
        jmp get_priority_ret
    get_priority_err:
        mov whole_error, 1
    get_priority_ret:
        pop dx
        pop bx
        pop ax
        ret
get_priority endp


set_led_num proc
    ; ֻ��handle_number������ã�
    ; ��ʱled_count = �����������λ��
    ; led_count - 1 = ����ʾ������λ��
        push ax
        push bx
        push cx
        push dx
        push di
        mov  LedBuf+0,0ffh
        mov  LedBuf+1,0ffh
        mov  LedBuf+2,0ffh
        mov  LedBuf+3,0ffh
        mov di, 3
        mov bx, offset display_num
        mov ax, [bx]
        ;mov ax, 0ch
    ax_not_zero:

        mov bx, offset ledmap
        mov dx, 0
        mov cx, 10
        div cx
        add bx, dx
        mov dl, [bx]
        mov bx, offset ledbuf
        add bx, di
        mov [bx], dl
        dec di
        
        cmp ax, 0
        jne ax_not_zero
    set_led_num_ret:
        pop di
        pop dx
        pop cx
        pop bx
        pop ax
        ret
set_led_num endp



disp proc
        mov  bx,offset LEDBuf
        mov  cl,6               ;��6���˶ι�
        mov  ah,00100000b       ;����߿�ʼ��ʾ
    DLoop:
        mov  dx,OUTBIT
        mov  al,0
        out  dx,al              ;�����а˶ι�
        mov  al,[bx]
        mov  dx,OUTSEG
        out  dx,al

        mov  dx,OUTBIT
        mov  al,ah
        out  dx,al              ;��ʾһλ�˶ι�

        push ax
        mov  ah,1
        call Delay
        pop  ax

        shr  ah,1
        inc  bx
        dec  cl
        jnz  DLoop

        mov  dx,OUTBIT
        mov  al,0
        out  dx,al              ;�����а˶ι�
        ret
disp endp

delay proc                         ;��ʱ�ӳ���
        push  cx
        mov   cx,256
        loop  $
        pop   cx
        ret
delay endp

    ;�˶ι���ʾ��
    LedMap  db   0c0h,0f9h,0a4h,0b0h,099h,092h,082h,0f8h
            db   080h,090h,088h,083h,0c6h,0a1h,086h,08eh
    ;���붨��
    KeyTable db   07h,04h,08h,05h,09h,06h,0ah,0bh
            db   01h,00h,02h,0fh,03h,0eh,0ch,0dh

code    ends
        end start
