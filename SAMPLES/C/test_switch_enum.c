enum color { RED, GREEN, BLUE };

int main() {
    enum color c;
    int r;
    
    c = GREEN;
    
    switch(c) {
        case RED:
            r = 10;
            break;
        case GREEN:
            r = 20;
            break;
        case BLUE:
            r = 30;
            break;
    }
    
    return r;
}
