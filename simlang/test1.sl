from = 0;
to = 1000;
echo("������� ����� �� ", from, " �� ", to, ", � � ���� ���������\n");
while (from <= to) {
    guess = ((from + to) / 2);
    echo("��� ", guess, "? (1=������, 2=������, 3=�����) ");
    i = input();
    if (i == 1) {
        to = (guess - 1);
    } else {
        if (i == 2) {
            from = (guess + 1);
        } else {
            if (i == 3) {
                echo("���! � �������!\n");
                exit;
            } else {
                echo("� ������ �� �����!\n");
            }
        }
    }
}
echo("����, ��� �� ������!\n");