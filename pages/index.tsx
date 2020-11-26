import * as React from 'react';
import { NextPage } from 'next';
import styled from 'styled-components';
import { safeLoad } from 'js-yaml';
import Button from '@material-ui/core/Button';
import TextField from '@material-ui/core/TextField';
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';

type PropsType = {
  allLang: {
    lang: string;
    type: string;
    color: string;
  }[];
};

type LanguageType = {
  name: string;
  value: number;
  color: string;
}[];

const App: NextPage<PropsType> = ({ allLang }) => {
  const [userName, setUserName] = React.useState('');
  const [langs, setLangs] = React.useState<LanguageType>([]);
  const inputHandler = (e: React.ChangeEvent<HTMLInputElement>) => {
    setUserName(e.target.value);
  };
  const clickHandler = async () => {
    const langsArray: string[] = [];
    let page = 1;
    const userUrl = `https://api.github.com/search/users?q=${encodeURI(
      userName
    )}`;
    const userRes = await fetch(userUrl);
    const userData = await userRes.json();
    console.log(userData);
    while (true) {
      const reposUrl = `https://api.github.com/users/${encodeURI(
        userName
      )}/repos?per_page=100&page=${page}`;
      const reposRes = await fetch(reposUrl);
      const reposData = await reposRes.json();
      if (reposData.length === 0) break;
      langsArray.push(
        ...reposData
          .filter(
            ({ fork, language }) =>
              language && !fork && allLang.find(({ lang }) => lang === language)
          )
          .map(({ language }) => language)
      );
      page++;
    }
    const langNames = [...new Set(langsArray)];
    setLangs(
      langNames.map(l => ({
        name: l,
        value: langsArray.filter(lang => lang === l).length,
        color: allLang.find(({ lang }) => lang === l).color
      }))
    );
  };
  return (
    <StyledArea>
      <h1>Language percentage in Github repository</h1>
      <TextField
        label="User Name"
        value={userName}
        onChange={inputHandler}
        fullWidth
      />
      <Button
        variant="contained"
        color="primary"
        onClick={clickHandler}
        fullWidth
      >
        Search
      </Button>
      <ResponsiveContainer width="100%" height="80%">
        <PieChart>
          <Pie dataKey="value" data={langs} label={({ name }) => name}>
            {langs.map(({ color }) => (
              <Cell key={`${Math.random()}`} fill={color} />
            ))}
          </Pie>
          <Tooltip />
        </PieChart>
      </ResponsiveContainer>
    </StyledArea>
  );
};

const StyledArea = styled.div`
  width: 100%;
  height: 100%;
  padding: 16px;
  > h1 {
    font-size: 32px;
    font-weight: bold;
    margin-bottom: 16px;
  }
  > button {
    margin-top: 16px;
  }
`;

export async function getStaticProps() {
  const res = await fetch(
    'https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml'
  );
  const allLanguageYml = await res.text();
  const allLanguageObj = safeLoad(allLanguageYml);
  const allLang = Object.keys(allLanguageObj)
    .filter(k => allLanguageObj[k].color)
    .map(key => ({
      lang: key,
      type: allLanguageObj[key].type,
      color: allLanguageObj[key].color
    }));
  return {
    props: {
      allLang
    }
  };
}

export default App;
