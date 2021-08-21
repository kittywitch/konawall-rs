use std::path::{Path, PathBuf};
use std::str::{self, FromStr};
use tempfile::tempdir;
use serde::Deserialize;
use std::io::Write;
use std::fs::File;
use anyhow::Result;
use std::future::Future;
use futures::future::try_join_all;
use structopt::StructOpt;
use tokio::process::Command;
use rand::seq::SliceRandom;
use swayipc_async::Connection;
use xrandr::XHandle;
use tokio::time::{sleep, Duration};
use std::iter;

#[derive(Deserialize, Debug)]
struct Post {
    file_url: String,
    id: u32,
}

#[derive(Deserialize, Debug)]
struct Failure {
    reason: String,
}

async fn get_files <'p> (dir: &'p Path, common_tags: &str, tags: &str, count: u8) -> Result<Vec<impl Future <Output=Result<PathBuf>> +'p>>  {
    let tags_appended = format!("{}{}{}", &common_tags, tags, "+order:random");
    let url_with_parameters = format!("https://konachan.com/post.json?limit={}&tags={}", count, tags_appended);
    let response = reqwest::get(url_with_parameters).await?;
    if response.status().is_success() {
        let response_json: Vec<Post> = response.json().await?;
        Ok(response_json.into_iter().map( |post|
            {
                println!("{} - {:?}", tags, post.file_url);
                get_file(dir, post)
            }
        ).collect())
    } else {
        let response_json: Failure = response.json().await?;
        Err(anyhow::format_err!(response_json.reason))
    }
}

async fn get_file(dir: &Path, post: Post) -> Result<PathBuf> {
    let url_extension = post.file_url.split(".").last().ok_or(anyhow::format_err!("no extension"))?;
    let file_path = dir.join(&format!("{}.{}", post.id, url_extension));

    let mut image_request = reqwest::get(post.file_url).await?;
    let mut file = File::create(&file_path)?;

    while let Some(chunk) = image_request.chunk().await? {
        file.write_all(&chunk)?;
    };
    Ok(file_path)
}

async fn set_sway_wallpaper(sway_conn: &mut Connection, output: swayipc_async::Output, filename: PathBuf) -> Result<()> {
    let wallpaper_path = filename.as_path().display().to_string();
    sway_conn.run_command(format!("output {} background {} fill", output.name, wallpaper_path)).await?;
    Ok(())
}

async fn set_i3_wallpaper(filenames: Vec<PathBuf>) -> Result<()> {
    Command::new("feh")
        .args(&["--no-fehbg", "--bg-fill"])
        .args(filenames)
        .status()
        .await
        .expect("feh command failed to start");
    Command::new("xsetroot")
        .args(&["-cursor_name", "left_ptr"])
        .status()
        .await
        .expect("xsetroot command failed to start");
    Ok(())
}

#[derive(Debug, StructOpt)]
enum WMs {
    I3,
    Sway,
}

impl FromStr for WMs {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "i3" => Ok(WMs::I3),
            "sway" => Ok(WMs::Sway),
            _ => Err(anyhow::format_err!("Unimplemented WM {}", s)),
        }
    }
}

#[derive(Debug, StructOpt)]
enum Modes {
    Random,
    OutputMap,
    OutputMapShuffle,
}

impl FromStr for Modes {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "random" => Ok(Modes::Random),
            "map" => Ok(Modes::OutputMap),
            "shuffle" => Ok(Modes::OutputMapShuffle),
            _ => Err(anyhow::format_err!("Unimplemented mode {}", s)),
        }
    }
}

#[derive(Debug, StructOpt)]
#[structopt(name = "konawall", about = "wallpaper randomizer that uses konachan")]
struct Opt {
    #[structopt(default_value="nobody")]
    tags: Vec<String>,
    #[structopt(long)]
    wm: WMs,
    #[structopt(long, default_value="score:>=200+width:>=1600+")]
    common: String,
    #[structopt(long, default_value="random")]
    mode: Modes,
}

async fn filenames_get(outputs: usize, temp_dir: &Path, mode: Modes, common_tags: &str, tag_list: &Vec<String>) -> Result<Vec<PathBuf>> {
    let mut filenames = Vec::new();

    let mut rng_random = &mut rand::thread_rng();
    let mut rng_shuffle = &mut rand::thread_rng();
    let mut mode_random = iter::from_fn(|| tag_list.choose(&mut rng_random));
    let mut mode_map = tag_list.iter().cycle();
    let mut mode_shuffle = iter::repeat_with(|| tag_list.choose_multiple(&mut rng_shuffle, outputs)).flat_map(|i| i);
    let tag_set = iter::from_fn(|| match mode {
        Modes::Random => mode_random.next(),
        Modes::OutputMap => mode_map.next(),
        Modes::OutputMapShuffle => mode_shuffle.next(),
    });

    for (_, tag) in (0..outputs).zip(tag_set) {
        filenames.extend(get_files(temp_dir, common_tags, tag, 1).await?);
    }

    let filenames = try_join_all(filenames).await?;

    Ok(filenames)
}

#[tokio::main]
async fn main() -> Result<()> {
    let temp_dir = tempdir()?;

    let opt = Opt::from_args();
    let tag_list = opt.tags;
    let common_tags = opt.common;
    let mode = opt.mode;

    let mut sway_conn: swayipc_async::Connection;

    match opt.wm {
        WMs::I3 => {
            let outputs = XHandle::open()?.monitors()?;
            let filenames = filenames_get(outputs.len(), &temp_dir.path(), mode, &common_tags, &tag_list).await?;
            set_i3_wallpaper(filenames).await?
        },
        WMs::Sway => {
            sway_conn = Connection::new().await?;
            let outputs = sway_conn.get_outputs().await?;
            let filenames = filenames_get(outputs.len(), &temp_dir.path(), mode, &common_tags, &tag_list).await?;
            for (output, filename) in outputs.into_iter().zip(filenames) {
                set_sway_wallpaper(&mut sway_conn, output, filename).await?;
            };
            sleep(Duration::from_millis(250)).await;
            ()
        },
    };

    Ok(())
}
