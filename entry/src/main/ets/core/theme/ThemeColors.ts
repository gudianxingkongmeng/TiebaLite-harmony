export const ThemeColors = {
  TIEBA_BLUE: { light: '#A0C4FF', dark: '#8AB4F8' },
  BLUE_VIOLET: { light: '#D0A0FF', dark: '#C68EF2' },
  JADE_GREEN: { light: '#80D8CC', dark: '#4DD0A8' },
  MERLOT_PINK: { light: '#F8CDE0', dark: '#F5C4D8' },
  SUNSET_ORANGE: { light: '#FFC49A', dark: '#FEAD80' },

  GREY_50: '#FAFAFA',
  GREY_100: '#F5F5F5',
  GREY_200: '#EEEEEE',
  GREY_300: '#E0E0E0',
  GREY_400: '#BDBDBD',
  GREY_500: '#9E9E9E',
  GREY_600: '#757575',
  GREY_700: '#616161',
  GREY_800: '#424242',
  GREY_900: '#212121',

  BLUE_200: '#90CAF9',
  BLUE_GREY_700: '#455A64',
  GREEN_700: '#388E3C',
  GREEN_800: '#2E7D32',
  CYAN_700: '#0097A7',
  CYAN_800: '#00838F',
  ORANGE_A700: '#FF6D00',
  YELLOW_A700: '#FFD600',
  PURPLE_100: '#E1BEE7',
  PURPLE_700: '#7B1FA2',
  PURPLE_800: '#6A1B9A',
  RED_A700: '#D50000',
  RED_700: '#D32F2F',
  RED_800: '#C62828'
};

export interface ThemeDefinition {
  name: string;
  primaryLight: string;
  primaryDark: string;
  secondaryLight: string;
  secondaryDark: string;
  tertiaryLight: string;
  tertiaryDark: string;
  swatch: string;
}

export const BUILTIN_THEMES: ThemeDefinition[] = [
  {
    name: '宝石蓝', primaryLight: '#475D92', primaryDark: '#B0C6FF',
    secondaryLight: '#575E71', secondaryDark: '#C0C6DC',
    tertiaryLight: '#5F5791', tertiaryDark: '#C8BFFF', swatch: '#4477E0'
  },
  {
    name: '葡萄紫', primaryLight: '#6E528A', primaryDark: '#DAB9F9',
    secondaryLight: '#575992', secondaryDark: '#C0C1FF',
    tertiaryLight: '#804D79', tertiaryDark: '#F1B3E6', swatch: '#8A2BE2'
  },
  {
    name: '翡翠绿', primaryLight: '#1B6B51', primaryDark: '#8BD6B6',
    secondaryLight: '#4C6358', secondaryDark: '#B3CCBF',
    tertiaryLight: '#166684', tertiaryDark: '#8DCFF1', swatch: '#019C74'
  },
  {
    name: '樱花粉', primaryLight: '#8C4A60', primaryDark: '#FFB0C8',
    secondaryLight: '#904B3E', secondaryDark: '#FFB4A6',
    tertiaryLight: '#8E4958', tertiaryDark: '#FFB2BF', swatch: '#E986A7'
  },
  {
    name: '落日橘', primaryLight: '#8E4D2F', primaryDark: '#FFB596',
    secondaryLight: '#865319', secondaryDark: '#FDB975',
    tertiaryLight: '#675F30', tertiaryDark: '#D2C78F', swatch: '#FD742D'
  },
  {
    name: '奶油白', primaryLight: '#475D92', primaryDark: '#B0C6FF',
    secondaryLight: '#575E71', secondaryDark: '#C0C6DC',
    tertiaryLight: '#5F5791', tertiaryDark: '#C8BFFF', swatch: '#FFF2CC'
  },
  {
    name: '曜石黑', primaryLight: '#475D92', primaryDark: '#B0C6FF',
    secondaryLight: '#575E71', secondaryDark: '#C0C6DC',
    tertiaryLight: '#5F5791', tertiaryDark: '#C8BFFF', swatch: '#212121'
  }
];

export const RECOMMENDED_COLORS: string[] = [
  '#4477E0', '#8A2BE2', '#019C74', '#E986A7', '#FD742D',
  '#B0C6FF', '#DAB9F9', '#8BD6B6', '#FFB0C8', '#FFB596',
  '#212121', '#FFFFFF'
];
