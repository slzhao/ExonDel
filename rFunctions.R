######################
#functions
######################
sigNumber<-function(rawData,cutoff1,cutoff2=10,winLen=7) {
	if (max(rawData,na.rm=T)<=cutoff2) {return(c(0,""))}
	if (length(na.omit(rawData))<winLen) {return(c(0,""))}
	result<-0
	sigExonNum<-""
	for (x in 1:(length(rawData)-winLen+1)) {
		if ((max(rawData[x:(x+winLen-1)],na.rm=T)<=cutoff1)) {
			result<-result+1
			sigExonNum<-paste(sigExonNum,x,sep=" ")
		}
	}
	return(c(result,sigExonNum))
}

read.bigFile<-function(myfile,header = TRUE,type="txt",skip=0,preRow=20,knownColC=NULL,knownColN=NULL,...) {
	if (header ==T && skip==0) {
		skip<-1
	}
	if (type=="txt") {
		tab2rows <- read.delim(myfile,header = F , nrows = preRow,skip=skip,as.is=T)
		classes <- sapply(tab2rows, class)
		classes[classes=="logical"]<-"character"
		if (is.null(knownColC)) {} else {
			knownColC<-knownColC[which(knownColC<=ncol(tab2rows))]
			classes[knownColC]<-"character"
		}
		if (is.null(knownColN)) {} else {
			knownColN<-knownColN[which(knownColN<=ncol(tab2rows))]
			classes[knownColN]<-"numeric"
		}
		tabAll <- read.delim(myfile, header = F, colClasses = classes,skip=skip,...)
		if (header ==T) {
			temp<-readLines(myfile,n=1)
			temp<-strsplit(temp,"\t")[[1]]
			if (length(temp)==(ncol(tabAll)+1)) {temp<-temp[-1]} else if (length(temp)!=ncol(tabAll)) {print("Not same col")}
			colnames(tabAll)<-temp
		}
	} else if (type=="csv") {
		tab2rows <- read.csv(myfile,header = F , nrows = preRow,skip=skip,as.is=T)
		classes <- sapply(tab2rows, class)
		classes[classes=="logical"]<-"character"
		if (is.null(knownColC)) {} else {
			knownColC<-knownColC[which(knownColC<=ncol(tab2rows))]
			classes[knownColC]<-"character"
		}
		if (is.null(knownColN)) {} else {
			knownColN<-knownColN[which(knownColN<=ncol(tab2rows))]
			classes[knownColN]<-"numeric"
		}
		tabAll <- read.csv(myfile, header = F, colClasses = classes,skip=skip,...)
		if (header ==T) {
			temp<-readLines(myfile,n=1)
			temp<-strsplit(temp,",")[[1]]
			if (length(temp)==(ncol(tabAll)+1)) {temp<-temp[-1]} else if (length(temp)!=ncol(tabAll)) {print("Not same col")}
			temp<-gsub("\"","",temp)
			colnames(tabAll)<-temp
		}
	}
	return(tabAll)
}

######################
#codes
######################
resultDir<-commandArgs()[5]
cfgFile<-commandArgs()[6]
selectGeneFlag<-commandArgs()[7]
fileNameAll<-paste(resultDir,'/genesPassQCwithGC.bed.depth.all',sep="")

#load data
if (file.exists(fileNameAll)) {
	print(paste0("Loading ",fileNameAll," to R"))
	exonAll<-read.bigFile(fileNameAll,header=T,knownColC=c(1,4,5),knownColN=c(6:500))
} else {
	fileNameExon<-paste(resultDir,'/genesPassQCwithGC.bed',sep="")
	fileNameDepth<-paste(fileNameExon,'.depth',sep="")
	print(paste0("Loading ",fileNameExon," to R"))
	exonAll<-read.bigFile(fileNameExon,header=F,knownColC=c(1,4,5))
	print(paste0("Loading ",fileNameDepth," to R"))
	exonDepth<-read.bigFile(fileNameDepth,header=F,row.names=1,knownColN=c(2:(nrow(exonAll)+1)))
	colnames(exonAll)<-c("chr","start","end","gene","transcript","GC")
	exonAll<-cbind(exonAll,t(exonDepth))
	write.table(exonAll,fileNameAll,row.names = F,quote =F,sep="\t")
}

#prepare data
cfg<-read.table(cfgFile, sep="=", as.is=T,comment.char = "#",fill=T,header=F,row.names=1)
minWinLength<-as.numeric(cfg["minWinLength",1])
maxWinLength<-as.numeric(cfg["maxWinLength",1])
minExonNum<-as.numeric(cfg["minExonNum",1])
if (selectGeneFlag) {
	adjustGC<-F
	minQuantile1<-as.numeric(cfg["cutoff1",1])
	minQuantile2<-as.numeric(cfg["cutoff2",1])
	print(paste0("Reads ",minQuantile1," and ",minQuantile2," will be used as cutoff in exon deletion detection"))
} else {
	minQuantile1<-as.numeric(cfg["cutoffQuantile1",1])
	minQuantile2<-as.numeric(cfg["cutoffQuantile2",1])
	adjustGC<-cfg["adjustGC",1]
	print(paste0("Quantile ",minQuantile1," and ",minQuantile2," of all reads for each sample will be used as cutoff in exon deletion detection"))
}

figureDir<-paste(resultDir,"/figures/",sep="")
dir.create(figureDir, showWarnings = FALSE)

#GC adjust
if (adjustGC) {
	exonAllOld<-exonAll
	groupsByGC<-cut(exonAll$GC,breaks=(0:10)/10,include.lowest=T)
	for (x in 7:ncol(exonAll)) {
		medianAll<-median(exonAll[,x],na.rm=T)
		medianByGC<-tapply(exonAll[,x],groupsByGC,median,na.rm=T)
		adjustFactorByGC<-medianAll/medianByGC
		adjustFactorByGC[which(is.na(adjustFactorByGC))]<-1
		exonAll[,x]<-round(exonAll[,x]*as.numeric(adjustFactorByGC[groupsByGC]),2)
	}
	write.table(exonAll,paste(fileNameAll,".adjustGC.txt",sep=""),row.names = F,quote =F,sep="\t")
}

#analysis data
for (winLength in minWinLength:maxWinLength) {
	results<-NULL
	resultsDetailList<-NULL
	resultsCutoffs<-NULL
	for (x in 7:ncol(exonAll)) {
		if (selectGeneFlag) {
			cutoff1<-minQuantile1
			cutoff2<-minQuantile2
		} else {
			cutoff1<-quantile(exonAll[,x],minQuantile1,na.rm=T) #find exons less than cutoff1
			cutoff2<-quantile(exonAll[,x],minQuantile2,na.rm=T) #the max count exon should be more than cutoff2 
		}
		temp1<-split(exonAll[,x],exonAll[,5])
		temp3<-which(sapply(temp1,length)>=minExonNum)
		if (length(temp3)==0) {
			stopText<-paste0("No gene has more than ",minExonNum," exons. Try to decrease minExonNum in configure file to allow more genes in exon deletion detection.")
			stop(stopText)
		} else {
			temp1<-temp1[temp3]
		}
		temp2<-sapply(temp1,function(x) {c(sigNumber(x,cutoff1=cutoff1,cutoff2=cutoff2,winLen=winLength),names(x))})
		results<-cbind(results,as.numeric(temp2[1,]))
		resultsDetailList<-cbind(resultsDetailList,temp2[2,])
		resultsCutoffs<-cbind(resultsCutoffs,c(cutoff1,cutoff2))
	}
	row.names(results)<-row.names(resultsDetailList)
	colnames(results)<-colnames(exonAll)[7:ncol(exonAll)]
	colnames(resultsDetailList)<-colnames(exonAll)[7:ncol(exonAll)]
	row.names(resultsCutoffs)<-c("cutoff1","cutoff2")
	colnames(resultsCutoffs)<-colnames(exonAll)[7:ncol(exonAll)]

	#export all results
	resultsExport<-NULL
	resultsCount<-which(results>0,arr.ind=T)
	if (nrow(resultsCount)>0) {
		png(paste(figureDir,"/exonDelsBy",winLength,".csv.png",sep=""),width=1000,height=300,res=150)
		par(mfrow=c(1,4))
		par(mar=c(2,2,2,1))
		for (x in 1:nrow(resultsCount)) {
			selectedName<-row.names(resultsCount)[x]
			selectedSample<-colnames(results)[resultsCount[,2][x]]
			temp1<-paste(exonAll[which(exonAll$transcript==selectedName),c("start")],collapse=";")
			temp2<-paste(exonAll[which(exonAll$transcript==selectedName),c("end")],collapse=";")
			temp3<-paste(exonAll[which(exonAll$transcript==selectedName),selectedSample],collapse=";")
			temp4<-as.character(exonAll[which(exonAll$transcript %in% selectedName)[1],c("gene","transcript","chr")])
			temp5<-resultsDetailList[selectedName,selectedSample]
			temp5<-gsub("^ ","",temp5)
			temp5<-gsub(" ",";",temp5)
			temp6<-range(as.numeric(strsplit(temp5,";")[[1]]),na.rm=T)
			temp7<-exonAll[which(exonAll$transcript==selectedName),c("start")][temp6[1]]
			temp8<-exonAll[which(exonAll$transcript==selectedName),c("end")][temp6[2]+winLength-1]
			resultsExport<-rbind(resultsExport,c(temp4,temp1,temp2,selectedSample,temp3,temp5,temp7,temp8))
			if (x<=4) {
				plot(exonAll[which(exonAll$transcript==selectedName),selectedSample],type="h",main=paste(selectedSample,paste(selectedName,exonAll[which(exonAll$transcript==selectedName)[1],"gene"],sep=":"),sep="\n"),las=1,ylab="Depth")
				sigExonAllPos<-as.numeric(strsplit(resultsDetailList[selectedName,selectedSample]," ")[[1]])
				temp<-NULL
				for (sigExonPos in na.omit(sigExonAllPos)) {
					temp<-c(temp,sigExonPos:(sigExonPos+winLength-1))
				}
				temp<-unique(temp)
				points(temp,rep(max(exonAll[which(exonAll$transcript==selectedName),selectedSample],na.rm=T),length(temp)),pch=17,col="red")
			}
		}
		dev.off()
		colnames(resultsExport)<-c("gene","transcript","chr","exonsStart","exonsEnd","sample","exonsDepth","exonDeletions","exonDeletionsStart","exonDeletionsEnd")
		fileExport1<-paste(resultDir,'/exonDelsBy',winLength,'.csv',sep="")
		write.csv(resultsExport,fileExport1,row.names=F)
		#resultsCutoffs<-cbind(cutoff=row.names(resultsCutoffs),resultsCutoffs)
		#write.csv(resultsCutoffs,fileExport2,row.names=F)
	} else {
		print(paste0("Can't find any exon deletions with ",winLength, " windows length\n"))
	}
	fileExport2<-paste(resultDir,'/exonDelsCutoffs.csv',sep="")
	resultsCutoffs<-cbind(cutoff=row.names(resultsCutoffs),resultsCutoffs)
	write.csv(resultsCutoffs,fileExport2,row.names=F)
}


