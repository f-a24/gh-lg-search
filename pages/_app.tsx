import App from 'next/app';
import { createGlobalStyle } from 'styled-components';
import { Reset } from 'styled-reset';

const GlobalStyle = createGlobalStyle`
  html, body {
    height: 100%;
    background-color: #fff;
  }
  #__next {
    height: 100%;
  }
  * {
    box-sizing: border-box;
  }
`;

export default class extends App {
  render() {
    const { Component, pageProps } = this.props;
    return (
      <>
        <Reset />
        <GlobalStyle />
        <Component {...pageProps} />
      </>
    );
  }
}
