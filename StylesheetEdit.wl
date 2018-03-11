(* ::Package:: *)

(* ::Title:: *)
(*StyleSheetEdit*)


BeginPackage["StyleSheetEdit`"]


StyleSheetCells::usage=
	"Gets the cells in the current stylesheet that match a given style.
Styles can be specified by a String, Symbol, or StyleData expression or a list thereof";
StyleSheetEdit::usage=
	"Applies the options given to the given cell styles in the given notebook";
StyleSheetNew::usage=
	"Creates a new style cell with a given name and optional parent style and options";
StyleSheetDelete::usage="Deletes all matching style cells";


(* ::Subsection:: *)
(*Undocumented*)


BeginPackage["`Undocumented`"];


(* ::Subsubsection::Closed:: *)
(*Styles*)


$StyleSheetTitleCellStyles::usage="The styles that are section-like";
$StyleSheetSectionCellStyles::usage="The styles that are section-like";
$StyleSheetIOCellStyles::usage="The styles that are code-like";
$StyleSheetTextCellStyles::usage="The styles that are text-like";


$StyleSheetCellDisplayStyleOptions::usage=
	"A listing of cell style options to make two cells look the same";


(* ::Subsubsection::Closed:: *)
(*New*)


StyleSheetOpen::usage="Opens the style definitions notebook for a given notebook";
StyleSheetTemplate::usage=
	"Creates a stylesheet editing template
-Create in the current document by default
-Opens a new one when passed Notebook[<ssname>] as the first argument";
StyleSheetUpdate::usage="StyleSheetDelete + StyleSheetNew";


StyleSheetDefaultStyles::usage="Sets a default styling cascade";


(* ::Subsubsection::Closed:: *)
(*Notebook*)


$DefaultStyleSheetNotebook::usage=
	"Default.nb hidden notebook";(*
StyleSheetNotebookFind::usage=
	"Finds the notebook for a given stylesheet";*)


StyleSheetNotebookObject::usage=
	"The style notebook object for editing a given notebook";
StyleSheetParentNotebook::usage=
	"Returns the NotebookObject that stores the styles of a given NotebookObject";
StyleSheetNotebookGet::usage=
	"NotebookGets the StyleSheetParentNotebook";
StyleSheetStyles::usage=
	"Gets the styles from a stylesheet";


(* ::Subsubsection::Closed:: *)
(*Edit*)


StyleSheetApplyEdits::usage=
	"Applies the edits from StyleSheetEdit";
StyleSheetDrop::usage"Drops the options given from the given cell styles in the given notebook";
StyleSheetValue::usage=
	"Gets the value of a style option for a cell style";
StyleSheetSync::usage="Copies style options from one style to another";


StyleSheetEditEvents::usage=
	"Edits the \[Star]EventActions";
StyleSheetEditAliases::usage=
	"Edits the InputAliases";
StyleSheetEditAutoReplacements::usage=
	"Edits the InputAutoReplacements";
StyleSheetEditTaggingRules::usage=
	"Edits the TaggingRules";


(* ::Subsubsection::Closed:: *)
(*Style Attributes*)


StyleDefinitionsValue::usage="experimental";


(* ::Subsubsection:: *)
(*End Undocumented*)


EndPackage[];


(* ::Section:: *)
(*Private*)


Begin["`Private`"];


(* ::Subsubsection::Closed:: *)
(*frontEndExecuteBlock*)


If[!ValueQ[$frontEndExecuteBlock],
	$frontEndExecuteBlock=False;
	$frontEndExecuteBlock//Protect
	]


frontEndExecuteSow[e_]:=
	Sow[e, "FrontEndExecute"];
frontEndExecuteRouter[a_,b_]:=
	If[$frontEndExecuteBlock,
		frontEndExecuteSow[a],
		b
		];
frontEndExecuteRouter~SetAttributes~HoldAllComplete;
frontEndExecuteBlock[e_]/;!TrueQ[$frontEndExecuteBlock]:=
	Block[{$frontEndExecuteBlock=True},
		With[{rd=Reap[e,"FrontEndExecute"]},
			Replace[rd[[2]],
				{a:{__}}:>
					If[MemberQ[a, _Hold],
						MathLink`CallFrontEndHeld@@
							Append[
							 Thread[Replace[a, h:Except[_Hold]:>Hold[h]],Hold],
							 System`FrontEndDump`NoResult
							 ],
						MathLink`CallFrontEnd[a, System`FrontEndDump`NoResult]
						]
				];
			rd[[1]]
			]
		];
frontEndExecuteBlock[e_]/;TrueQ[$frontEndExecuteBlock]:=e;
frontEndExecuteBlock~SetAttributes~HoldAllComplete;


(* ::Subsubsection::Closed:: *)
(*Styles*)


$StyleSheetTitleCellStyles={"Title","Chapter","Subchapter"};
$StyleSheetSectionCellStyles={"Section","Subsection","Subsubsection","Subsubsubsection"};
$StyleSheetIOCellStyles={"Input","Code","Output"};
$StyleSheetTextCellStyles={"Text","Item","ItemParagraph","Subitem","SubitemParagraph"};


$StyleSheetCellTextStyleOptions=
	{
		FontSize,
		FontColor,
		FontSlant,
		FontWeight,
		TabSpacings
		};


Off[General::shdw];
System`CellFrameStyle;
System`GroupOpenerColor;
System`GroupOpenerInsideFrame;
On[General::shdw];


$StyleSheetCellFrameStyleOptions=
	{
		CellFrame,
		Background,
		CellFrameColor,
		System`CellFrameStyle
		};


$StyleSheetCellSpacingStyleOptions=
	{
		CellMargins,
		CellFrameMargins
		};


$StyleSheetCellDisplayStyleOptions:=
	Join[
		$StyleSheetCellTextStyleOptions,
		$StyleSheetCellFrameStyleOptions,
		$StyleSheetCellSpacingStyleOptions
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetNotebookFind*)


ssFENotebooks[f_String?FileExistsQ]:=
	List@SelectFirst[FrontEndExecute@FrontEnd`ObjectChildren[$FrontEnd],
Quiet@NotebookFileName@#===f&
		];
ssFENotebooks[Optional["*","*"]]:=
	FrontEndExecute@FrontEnd`ObjectChildren[$FrontEnd];
ssFENotebooks[pat:Except["*"|_String?FileExistsQ]]:=
	Select[FrontEndExecute@FrontEnd`ObjectChildren[$FrontEnd],
		Replace[Quiet@NotebookFileName@#,{
				s_String:>
					StringMatchQ[s,pat],
				_->False
				}
			]||
		Replace[Quiet@NotebookFileName@#,{
				s_String:>
					FileBaseName@StringMatchQ[s,pat],
				_->False
				}
			]||
		StringMatchQ[
			WindowTitle/.AbsoluteOptions[#,WindowTitle],
			pat
			]&
		]


StyleSheetNotebookFind//Clear
StyleSheetNotebookFind[name:_String|{__String}|_FrontEnd`FileName]:=
	Replace[
		FrontEndExecute@
			FrontEnd`FindFileOnPath[
				StringTrim[
					Replace[name, 
						{
							l_List:>FileNameJoin[l],
							f_FrontEnd`FileName:>ToFileName[f]
							}
							],
					".nb"
					]<>".nb",
				"StyleSheetPath"
				],
		{
			f_String?FileExistsQ:>
				Replace[
					ssFENotebooks@f,
					{
						{}->Missing["NotFound"],
						{nb_}:>nb
						}
					],
			_->Missing["FileNotFound"]
			}
		];


$DefaultStyleSheetNotebook:=
StyleSheetNotebookFind["Default"]


(* ::Subsubsection::Closed:: *)
(*ParentNotebook*)


ssFileName[file_]:=
	FrontEndExecute@
		FrontEnd`FindFileOnPath[
			StringTrim[
				Replace[file, 
					{
						l_List:>FileNameJoin[l],
						f_FrontEnd`FileName:>ToFileName[f]
						}
						],
				".nb"
				]<>".nb",
			"StyleSheetPath"
			]


ssNotebookInformationNotebook[nb_]:=
	Replace[
		Lookup[
			Replace[NotebookInformation[nb], Except[_?OptionQ]->{}],
			"StyleDefinitions"
			],
		{n_NotebookObject,___}:>n
		]


StyleSheetNotebookFileName[nb_NotebookObject]:=
	Replace[
		CurrentValue[nb,StyleDefinitions],
		{
			f:_String|_FrontEnd`FileName:>
				ssFileName[f],
			_Notebook:>
				Missing["NotAvailable"]
			}
		];


If[!AssociationQ@$ssNbObjCache,
	$ssNbObjCache=<||>
	];
StyleSheetParentNotebook[nb_NotebookObject]:=
	Replace[
		Replace[ssNotebookInformationNotebook[nb],
			Except[_NotebookObject?(NotebookInformation@#===$Failed&)]:>
			Lookup[$ssNbObjCache, nb]
			],
		{
			_Missing|_NotebookObject?(NotebookInformation@#===$Failed&):>
				Set[$ssNbObjCache[nb],
					First@
						Lookup[
							Replace[NotebookInformation[nb], Except[_?OptionQ]->{}],
							"StyleDefinitons",
							{
								Replace[StyleSheetNotebookFileName[nb],{
									f_String:>
										Replace[ssFENotebooks[f],{
											{}:>Missing["NotFound"],
											{n_,___}:>n
											}],
									_Missing:>
										With[{n=CurrentValue[nb,StyleDefinitions]},
											SelectFirst[ssFENotebooks[],
												NotebookGet@#===n&]
											]
									}]
								}
							]
					]
			}
		];
StyleSheetParentNotebook[name:_String|{__String}|_FrontEnd`FileName]:=
	Replace[StyleSheetNotebookFind[name],
		nb_NotebookObject:>StyleSheetParentNotebook[nb]
		]


StyleSheetParentNotebook/:
	HoldPattern[Unset[StyleSheetParentNotebook[nb_NotebookObject]]]:=
		$ssNbObjCache[nb]=.;
StyleSheetParentNotebook/:
	HoldPattern[Unset[StyleSheetParentNotebook[nb:EvaluationNotebook[]|InputNotebook[]]]]:=
		With[{n=nb},
			Unset[StyleSheetParentNotebook[n]]
			];
StyleSheetParentNotebook/:
	HoldPattern[Set[StyleSheetParentNotebook[nb_NotebookObject],n_NotebookObject]]:=
		$ssNbObjCache[nb]=n;
StyleSheetParentNotebook/:
	HoldPattern[
		Set[StyleSheetParentNotebook[nb:EvaluationNotebook[]|InputNotebook[]],
			n_NotebookObject]
		]:=
		With[{e=nb},
			Set[StyleSheetParentNotebook[e],n]
			];
StyleSheetParentNotebook/:
	HoldPattern[SetDelayed[StyleSheetParentNotebook[nb_NotebookObject],n_]]:=
		$ssNbObjCache[nb]:=n;
StyleSheetParentNotebook/:
	HoldPattern[
		SetDelayed[StyleSheetParentNotebook[nb:EvaluationNotebook[]|InputNotebook[]],
			n_]
		]:=
		With[{e=nb},
			SetDelayed[StyleSheetParentNotebook[e],n]
			];


(* ::Subsubsection::Closed:: *)
(*NotebookGet*)


StyleSheetNotebookGet[nb_NotebookObject]:=
	NotebookGet@StyleSheetParentNotebook@nb;
StyleSheetNotebookGet[Optional[Automatic,Automatic]]:=
	StyleSheetNotebookGet@EvaluationNotebook[];


(* ::Subsubsection::Closed:: *)
(*NotebookObject*)


StyleSheetNotebookObject[nb:_NotebookObject|Automatic:Automatic]:=
	With[{e=Replace[nb,Automatic:>EvaluationNotebook[]]},
		Replace[CurrentValue[e,StyleDefinitions],{
			"StylesheetFormatting.nb"|"PrivateStylesheetFormatting.nb"|
				Notebook[{___,
					Cell[
						StyleData[
							StyleDefinitions->
								("PrivateStylesheetFormatting.nb"|"StylesheetFormatting.nb")
							],
					___],
					___
					},
					___
					]->e,
			s:_String|_FrontEnd`FileName:>
				(
					SetOptions[e,
						StyleDefinitions->
							Notebook[{Cell[StyleData[StyleDefinitions->s]]},
								StyleDefinitions->
									("PrivateStylesheetFormatting.nb")
								]
						];
					$ssNbObjCache[e]=.;
					StyleSheetParentNotebook[e]
					),
			_:>
				StyleSheetParentNotebook[e]
			}]
		];
StyleSheetNotebookObject[name:_String|{__String}|_FrontEnd`FileName]:=
	Replace[StyleSheetNotebookFind[name],
		nb_NotebookObject:>StyleSheetNotebookObject[nb]
		]


(* ::Subsubsection::Closed:: *)
(*StyleSheetTemplate*)


StyleSheetTemplate[newNB:_Notebook|_NotebookObject|None:None,
	defaultStyle:_DefaultStyle:DefaultStyle["Default.nb"],
	styles:(_String|_Directive)...,
	ops:_Rule|_RuleDelayed...
	]:=With[{nb=Replace[newNB,{
			_Notebook:>
			CreateDocument["",
				ops,
				WindowTitle->First@newNB,
				StyleDefinitions->
					Notebook[{
						Cell[StyleData[StyleDefinitions->"StylesheetFormatting.nb"]],
						Cell[StyleData["Notebook"],
							Saveable->True,
							Editable->True
							]
						}],
					Saveable->True],
				None:>Automatic
				}]},
		StyleSheetNew[nb,defaultStyle,Next];
		Do[
			StyleSheetNew[nb,##]&@@If[MatchQ[s,_Directive],s,{s}],
			{s,{styles}}];
		Replace[nb,Automatic:>Null]
		];
StyleSheetTemplate[
	newNB:_Notebook|_NotebookObject|None:None,
	defaultStyle:_DefaultStyle:DefaultStyle["Default.nb"],
	Default]:=
	StyleSheetTemplate[newNB,defaultStyle,
		"Notebook",
		"Title","Chapter","Subchapter",
		"Section","Subsection","Subsubsection",
		"Text","Code","Input",
		"Item","ItemParagraph"
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetOpen*)


StyleSheetOpen[nb:_NotebookObject|Automatic:Automatic]:=
With[{notebook=Replace[nb,Automatic:>StyleSheetNotebookObject[]]},
	(*FrontEndTokenExecute@"EditStyleDefinitions";*)
Replace[
StyleDefinitions/.Options[notebook,StyleDefinitions],{
s:(_String|_FrontEnd`FileName):>
			SystemOpen@s,
n:(_Notebook):>
			CreateDocument[n,
				WindowTitle->"StyleDefintions for "<>FileNameTake@NotebookFileName[notebook]]
}
]
];


(* ::Subsubsection::Closed:: *)
(*StyleSheetDefaultStyles*)


StyleSheetDefaultStyles[
	nb:_NotebookObject|Automatic:Automatic,
	styles__String]:=
	With[{sList={styles}},
		Do[
			StyleSheetEdit[nb,sList[[i]],DefaultNewCellStyle->sList[[i+1]]],
			{i,Length@sList-1}
			]
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetStyleData*)


ssNormalizeStyleName[s_String]:=
	Replace[StringSplit[s, "/"],
		{
			{n_}:>n,
			{n__}:>StyleData[n]
			}
		];
ssNormalizeStyleName[e_]:=e


iStyleSheetStyleData[canonicalStyles_]:=
	Replace[
		canonicalStyles,
		{
			(Rule|RuleDelayed)[s_String, p_String]:>
				StyleData[s, StyleDefinitions->StyleData[p]],
			(Rule|RuleDelayed)[{s__String},p_String]:>
				StyleData[s, StyleDefinitions->StyleData[p]],
			(Rule|RuleDelayed)[s_String,{p__String}]:>
				StyleData[s, StyleDefinitions->StyleData[p]],
			(Rule|RuleDelayed)[{s__String}, {p__String}]:>
				StyleData[s, StyleDefinitions->StyleData[p]],
			e_:>
				StyleData[e]
			},
		1
		]//.{
			(Rule|RuleDelayed)[name:Except[StyleDefinitions],env_]:>
				StyleData@@Flatten@{name,env}
			}//.{
			DefaultStyle[f__]:>(
				StyleDefinitions->
					Replace[{f},{
						{s_String}:>
							StringTrim[s,".nb"]<>".nb",
						{path__,name_}:>
							FrontEnd`FileName[{path},
								Evaluate[StringTrim[name,".nb"]<>".nb"]],
						{e_}:>
							e
						}]
				),
			StyleData[a___, StyleData[b___], c___]:>
				StyleData[a,b,c]
			};
StyleSheetStyleData[styleNames_]:=
		iStyleSheetStyleData@Flatten@
			Replace[
				ssNormalizeStyleName/@Flatten[{styleNames}, 1],
				{
					(h:Rule|RuleDelayed)[s_List,e_]:>
							Map[Thread[h[#,e]]&,s],
					(h:Rule|RuleDelayed)[s_,e_List]:>
							Map[Thread[h[s,#]]&,e]
					},
				1
				];


(* ::Subsubsection::Closed:: *)
(*StyleSheetCells*)


$StyleSheetCellStyleBaseStylePattern=
	All|_String|_StyleData|_Verbatim|Default;
$StyleSheetCellStyleSubStylePattern=
	$StyleSheetCellStyleBaseStylePattern|{$StyleSheetCellStyleBaseStylePattern..}->
		$StyleSheetCellStyleBaseStylePattern|{$StyleSheetCellStyleBaseStylePattern..};
$StyleSheetCellStyleSinglePattern=
	$StyleSheetCellStyleBaseStylePattern|
		$StyleSheetCellStyleSubStylePattern|
		_?StringPattern`StringPatternQ


$StyleSheetCellStylePatterns=
	$StyleSheetCellStyleSinglePattern|{$StyleSheetCellStyleSinglePattern..};


cellTypeMatchQ//Clear


cellTypeMatchQ[type:_String|All, types_]:=
	Which[
		types==={"*"},
			True,
		types==={},
			False,
		MatchQ[types, StyleData[_]],
			cellTypeMatchQ[type, First@types],
		StringPattern`StringPatternQ[type],
			StringMatchQ[type,
				Alternatives@@
					Select[Flatten@List@types, StringPattern`StringPatternQ]
				],
		True,
			MemberQ[
				Replace[types,
					{s_, "*"..}:>{s},
					1
					],
				type
				]
		];
cellTypeMatchQ[type_Symbol, "*"]:=True;
cellTypeMatchQ[type:Except[_String],_]:=False;
cellTypeMatchQ[types_][type_]:=cellTypeMatchQ[type,types];


cellStyleMovingMatchQ[s_, types_]:=
	With[{styleDatas=
		Replace[
			Cases[Flatten@{types}, _StyleData|_Verbatim],
			{
				HoldPattern[Verbatim][d_StyleData]:>
					If[Length@d!=Length@s,
						Nothing,
						List@@d
						],
				HoldPattern[Verbatim][e_]:>
					If[Length@s!=1,
						Nothing,
						{e}
						],
				d_StyleData:>
					If[Length@d>Length@s,
						Nothing,
						Join[
							List@@d,
							ConstantArray["*", Max@{Length@s-Length@d,0}]
							]
						]
				},
			1]
			},
		AnyTrue[
			styleDatas,
				And@@MapThread[cellTypeMatchQ, {List@@s,#}]&
			]
		]


cellStyleNameMatchQ[
	s_StyleData,
	types_
	]:=
	types=!={}&&
		If[Length@s==1,
			cellTypeMatchQ[First@s, 
				First/@Select[types, Length@#==1&]
				],
			Length@s>0&&
				(
					cellTypeMatchQ[
						First@s,
						First/@Select[types, Length@#==1&]
						]||
					cellStyleMovingMatchQ[s, types]
					)
			];


cellStyleDataMatchQ[s_StyleData, types_]:=
	With[
		{
			matchData=
				DeleteCases[s, Except[_String|_Symbol|_?StringPattern`StringPatternQ]]
				},
		MatchQ[matchData,
			Alternatives@@
				Replace[
					Flatten@{types},
					{
						DefaultStyle[d_]:>
							StyleData[StyleDefinitions->d],
						DefaultStyle[p_List, f_String]:>
							StyleData[StyleDefinitions->FrontEnd`FileName[{p},f]],
						DefaultStyle[a__,b_]:>
							StyleData[StyleDefinitions->StyleData[a,b]]
						},
					1
					]
			]||
		cellStyleNameMatchQ[matchData, types]
		];
cellStyleDataMatchQ[types_][s_]:=
	cellStyleDataMatchQ[s, types];


cellMatchQ[cell_, types_, Optional[StyleData,StyleData]]:=
	Replace[
		cell,
		{
			Cell[_, _String, ___]:>
				False,
			Cell[
				If[types===Default,
					StyleData[StyleDefinitions->_,___],
					_StyleData?(cellStyleDataMatchQ[types])
					],
				___
				]:>
				True,
			Cell[
				_?(
					MatchQ[
						Replace[#,
							_BoxData:>ToExpression[#,StandardForm,Hold]
							],
						If[types===Default,
							StyleData[StyleDefinitions->_,___],
							_StyleData?(cellStyleDataMatchQ[types])
							]
						]&
					),
				___
				]:>
				True,
			_->
				False
			}
		];


cellMatchQ[cell_,types_,Normal]:=
	Replace[
		cell,
		{
			Cell[_, _?(cellTypeMatchQ[types]), ___]:>
				True,
			_:>
				False
			}
		];
cellMatchQ[cell_,types_,_]:=False


stylesheetNotebook[nb_,file_String?FileExistsQ]:=Get@file;
stylesheetNotebook[nb_,file_FrontEnd`FileName]:=Get@ToFileName@file;
stylesheetNotebook[nb_NotebookObject,file_String]:=
	stylesheetNotebook[NotebookGet@nb,Quiet@NotebookDirectory@nb,file];
stylesheetNotebook[
		nb_Notebook,
		dir:(_String?DirectoryQ|Automatic|$Failed):Automatic,
		file_String]:=
	With[{testDir=
		Replace[Quiet@NotebookDirectory@nb,
			_NotebookDirectory|$Failed:>
			Replace[dir,$Failed|Automatic:>$UserDocumentsDirectory]
			]},
		If[FileExistsQ@FileNameJoin@{testDir,file},
			Get@FileNameJoin@{testDir,file},
			Replace[Cases[Flatten@Table[
							FileNames["*",FileNameJoin@{d,"FrontEnd","Stylesheets"}],
									{d,
										FileNames["*",{
											FileNameJoin@{$UserBaseDirectory,"Applications"},
											$InstallationDirectory
										}]
									}],
							s_?(FileNameTake@#===file&):>s],
					{
						{}:>$Failed,
						{s_,___}:>Get@s
				}
					]
				]
		];


ssMakeEnvDatas[typeData_]:=
	Replace[
		ssNormalizeStyleName/@Flatten@List@typeData,
		(a_->b_):>
			StyleData[
				Sequence@@Flatten@{a},
				StyleDefinitions->
					StyleData[Sequence@@Flatten@{b}]
				],
		1
		];


StyleSheetCells//Clear
Options[StyleSheetCells]={
	"MakeCell"->False,
	"SelectMode"->StyleData,
	"DetectStylesheet"->True
	};
StyleSheetCells[
	nb:_Notebook|_NotebookObject|Automatic:Automatic,
	typeData:$StyleSheetCellStylePatterns|{},
	ops:OptionsPattern[]
	]:=
	With[{
		make=TrueQ@OptionValue["MakeCell"],
		mode=
			Replace[
				OptionValue["SelectMode"],
				Except[Normal|StyleData]->StyleData
				],
		types=
			DeleteCases[#, _Rule]&/@StyleSheetStyleData[typeData]
		},
		Replace[
			Select[
				(* get the CellObjects against which to match *)
				Replace[
					If[TrueQ@OptionValue["DetectStylesheet"],
						StyleSheetNotebookObject[nb],
						Replace[nb, Automatic:>EvaluationNotebook[]]
						],
					{
						n_NotebookObject:>Cells[n],
						n_Notebook:>(First@NotebookTools`FlattenCellGroups[n])
						}
					],
				cellMatchQ[Replace[#,c_CellObject:>NotebookRead@c], types, mode]&
				],
			{
				l_List:>
					If[mode===StyleData&&make,
						(* if there were styles that weren't found, make them *)
						With[
							{missingStyles=
								Select[
									Cases[Flatten[{types},1], _StyleData|_String],
									With[{c=NotebookRead/@l},
										With[{s=#},
											Not@AnyTrue[c, cellMatchQ[#, s, StyleData]&]
											]&
										]
									]
								},
							StyleSheetNew[nb, missingStyles];
							Join[
								StyleSheetCells[nb,
									missingStyles,
									"MakeCell"->False,
									ops
									],
								l
								]
							],
						l]	
				}
			]
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetNew*)


$StyleSheetNewCellStyles=
	$StyleSheetCellStylePatterns;
$StyleSheetNewParentStyles=
	_FrontEnd`FileName|_String|_StyleData|None|
			{(_FrontEnd`FileName|_String|_StyleData|None)..};


Options[StyleSheetNew]=
	DeleteDuplicatesBy[
		Join[
			Options[Cell],
			Options[Notebook],
			Options[NotebookWrite],
			{
				"DetectStylesheet"->True
				}
			],
		First];
StyleSheetNew[
	nb:_NotebookObject|Automatic:Automatic,
	type:$StyleSheetNewCellStyles,
	placement:Next|First|Last|Automatic:Automatic,
	ops:OptionsPattern[]
	]:=
	With[{
		ec=EvaluationCell[],
		notebook=
			If[TrueQ@OptionValue["DetectStylesheet"],
				StyleSheetNotebookObject[nb],
				Replace[nb, Automatic:>EvaluationNotebook[]]
				],
		position=
				Replace[placement,
					Automatic:>Replace[type,{_DefaultStyle->First,_->Next}]],
		styleDecs=
			StyleSheetStyleData[type]
		},
		Switch[position,
			First,SelectionMove[notebook,Before,Notebook],
			Next,SelectionMove[notebook,After,Cell],
			Last,SelectionMove[notebook,After,Notebook]
			];
		NotebookWrite[notebook,
			Cell[#,
				Sequence@@FilterRules[{ops},
					Except[Alternatives@@Map[First,Options[NotebookWrite]]]
					]
				],
			Sequence@@FilterRules[{ops},Options@NotebookWrite]
			]&/@styleDecs;
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetDelete*)


StyleSheetDelete[
	nb:_NotebookObject|Automatic:Automatic,
	type:_String|_List|_DefaultStyle]:=
	Replace[StyleSheetCells[nb,type],{
		c:{__CellObject}:>
			NotebookDelete@c
		}];


(* ::Subsubsection::Closed:: *)
(*StylesheetNotebook*)


StylesheetNotebook[nb:_Notebook|_NotebookObject|Automatic:Automatic]:=
	With[{n=Replace[nb,Automatic:>StyleSheetNotebookObject[]]},
		Module[{styleDefs=StyleDefinitions/.Options[n,StyleDefinitions],
				parentNB,extraStyles},
				parentNB=
					Replace[styleDefs,
						sd_Notebook:>
							Replace[StyleSheetCells[sd,Default],
								{
									{___,c_}:>Last@First@First@c,
									{}->Notebook[{}]
								}]
							];
				extraStyles=
					Replace[styleDefs,{
						sd_Notebook:>StyleSheetCells[sd],
						_:>{}
						}];
				If[MatchQ[parentNB,_String|_FrontEnd`FileName],
					parentNB=
						Replace[
							stylesheetNotebook[n,parentNB],
							s_String:>Get@s
							];
					parentNB
					];
				Replace[
					NotebookTools`FlattenCellGroups@parentNB,{
						Notebook[cells_List,o___]:>
							With[{styleNB=Notebook[Flatten@{cells,extraStyles}]},
								Notebook[Join[
									StyleSheetCells[styleNB,Default],
									StyleSheetCells[styleNB]],
									o]
								],
						_->parentNB
						}
					]
				]
			];


(* ::Subsubsection::Closed:: *)
(*Styles*)


StyleSheetStyles[nb:_Notebook|_NotebookObject|Automatic:Automatic]:=
	Module[
		{defaultCells=StyleSheetCells[nb,Default]},
		{
			With[{n=StylesheetNotebook@nb},
				defaultCells={
					defaultCells,
					If[n=!=$Failed,StyleSheetCells[n,Default],{}]};
					Cases[
						If[n=!=$Failed,
							StyleSheetCells[n],
							{}],
						Cell[StyleData[s:Except[_Rule]..,___Rule],___]:>Cell[StyleData[s]]
					]
				],
			Join@@defaultCells
		}
	];


(* ::Subsubsection::Closed:: *)
(*ApplyEdits*)


StyleSheetSuspendScreen[nb_]:=
	frontEndExecuteRouter[
		FrontEnd`NotebookSuspendScreenUpdates[nb],
		FrontEndExecute@
			FrontEnd`NotebookSuspendScreenUpdates[nb]
		]


StyleSheetResumeScreen[nb_]:=
	frontEndExecuteRouter[
		FrontEnd`NotebookResumeScreenUpdates[nb],
		FrontEndExecute@
			FrontEnd`NotebookResumeScreenUpdates[nb]
		]


StyleSheetSelectionMove[a___]:=
	frontEndExecuteRouter[
		FrontEnd`SelectionMove[a],
		SelectionMove[a]
		]


StyleSheetToggleShowExpr[nb_]:=
	frontEndExecuteRouter[
		frontEndExecuteSow[
			FrontEndToken[nb, "ToggleShowExpression"]
			],
		FrontEndTokenExecute[nb, "ToggleShowExpression"]
		]


StyleSheetApplyEdits[cells:{__CellObject}]:=
	With[{
		groups=GroupBy[cells,ParentNotebook],
		current=EvaluationCell[],
		inb=InputNotebook[]
		},
		KeyValueMap[
			With[{nb=#},
				If[$frontEndExecuteBlock//TrueQ,
					CheckAll,
					Function[Null, #, HoldAll]
					][
					StyleSheetSuspendScreen[nb];
					Map[
						StyleSheetSelectionMove[#,All,Cell,
							AutoScroll->False
							];
						StyleSheetToggleShowExpr[nb]~Do~2;
						&,
						#2
						];
					StyleSheetResumeScreen[nb],
					StyleSheetResumeScreen[nb]
					]
				]&,
			groups
			];
		If[inb===ParentNotebook@current,
			StyleSheetSelectionMove[current,All,Cell]
			];
		];
StyleSheetApplyEdits[nb:_CellObject|Automatic:Automatic]:=
	StyleSheetApplyEdits[{Replace[nb,Automatic:>EvaluationCell[]]}];


(* ::Subsubsection::Closed:: *)
(*SetOptions*)


StyleSheetSetOptions[obj_,ops__]:=
	If[$frontEndExecuteBlock,
		frontEndExecuteSow[
			FrontEnd`SetOptions[obj, ops]
			],
		SetOptions[obj,ops]
		]


(* ::Subsubsection::Closed:: *)
(*StyleSheetEdit*)


StyleSheetEdit//ClearAll


StyleSheetEdit[
	cellExprs:_Cell|{__Cell},
	conf:_?OptionQ
	]:=
	With[{cells=Flatten@{cellExprs}},
		With[{del=
			Alternatives@@Map[(Rule|RuleDelayed)[First@#,_]&,Flatten@{conf}]
			},
			Table[
				Join[
					DeleteCases[c,del],
					Cell[conf]/.(
						(h:Rule|RuleDelayed)[k_,f_Function]:>
							With[{o=f@(k/.Quiet@Options[c,k])},
								h[k,o]
								]
						)
					],
					{c,cells}
					]
				]
			]


$StyleSheetEditApplyFunctions=False;


StyleSheetEdit[
	cellObs:_CellObject|{__CellObject},
	conf_?OptionQ
	]:=
	frontEndExecuteBlock@
		With[{cells=Flatten@{cellObs}},
			Do[
				With[
					{
						oplist=
							If[$StyleSheetEditApplyFunctions,
								Table[
									If[MatchQ[o,_Rule],
										With[{op=Options[c,First@o]},
											Replace[op,
												{
													{k_->v_,___}:>
														(k->
															Replace[Last@o,
																f_Function:>(f[v,c])]
															),
													{}->o
													}
												]
											],
										o
										],
									{o, Flatten@{conf}}
									],
								Flatten@{conf}
								]
						},
					StyleSheetSetOptions[c, oplist]
					],
			{c,cells}
			];
		StyleSheetApplyEdits@cells;
		]


StyleSheetEdit[
	StyleData[nb:_NotebookObject],
	types:$StyleSheetCellStylePatterns,
	conf_?OptionQ
	]:=
		With[{snb=StyleDefinitions/.Options[nb,StyleDefinitions]},
			SetOptions[nb,
				StyleDefinitions->Replace[snb,{
					_Notebook:>
						With[{n=NotebookTools`FlattenCellGroups@snb},
							ReplacePart[n,
								1->With[{c=
										Replace[
											StyleSheetCells[n,StyleData,types],
											l_?(Length@#<Length@Flatten@{types}&):>
												With[{stypes=First/@First/@l},
														Join[l,
															Cell[StyleData[#]]&/@DeleteCases[Flatten@{types},
																Alternatives@@stypes]
															]
														]
											]},
											Join[
												DeleteCases[First@n,
													Alternatives@@DeleteDuplicates[
																Cell[StyleData[First@First@#,___],___]&/@c
															]
													],
												StyleSheetEdit[c,conf]
												]
										]
									]
							],
					_String:>
						Notebook[
							Prepend[
								StyleSheetEdit[Cell[StyleData[#]]&/@Flatten@{types},conf],
								Cell@StyleData[StyleDefinitions->snb]
								],
								StyleDefinitions->
									Notebook[{
										Cell[StyleData[StyleDefinitions->"StylesheetFormatting.nb"]],
										Cell[StyleData["Notebook"],
											Saveable->True,
											Editable->True
											]
										}]
								]
								
					}]
				]
			]


Options[StyleSheetEdit]=
	Join[
		Options[StyleSheetCells],
		{
			"ApplyFunctions"->False
			}
		];
StyleSheetEdit[
	nb:_NotebookObject|Automatic:Automatic,
	types:$StyleSheetCellStylePatterns,
	conf_?OptionQ,
	ops:OptionsPattern[]
	]:=
	Block[
	{
		$StyleSheetEditApplyFunctions=
			Replace[OptionValue["ApplyFunctions"],
				{
					Automatic:>Not@FreeQ[conf, Verbatim[Function][___, _Function, ___]],
					Except[True]->False
					}
				]
			},
		With[
			{
				cells=
					StyleSheetCells[nb,types,
						FilterRules[{ops}, Options[StyleSheetCells]]
						]
				},
			If[Length@cells===0,
				$Failed,
				StyleSheetEdit[cells, conf]
				]
			]
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetValue*)


$StyleSheetCellOptionPatterns=
	_String|_Symbol|{(_String|_Symbol)..};


Options[StyleSheetValue]=
	Join[
		Options[StyleSheetCells],
		{
			"ValueFunction"->CurrentValue
			}
		];
StyleSheetValue[
	cellOb:_CellObject|{__CellObject},
	ops:$StyleSheetCellOptionPatterns,(*
	part:_Integer|{Repeated[__Integer,2]}|_Span|All:All,*)
	OptionsPattern[]
	]:=
	With[{
		mode=
			Replace[OptionValue["ValueFunction"],{
				Automatic->CurrentValue,
				"Absolute"->AbsoluteCurrentValue
				}]
		},
		If[ListQ@cellOb,
			If[Length@cellOb>1,
				Transpose,
				Flatten[#,1]&
				](*[[part]]*),
			Identity
			]@
			Map[
				mode[cellOb,#]&,
				Flatten@{ops}
				]
		];
StyleSheetValue[
	nb:_NotebookObject|Automatic:Automatic,
	cellStyle:$StyleSheetCellStylePatterns,
	op:$StyleSheetCellOptionPatterns,
	ops:OptionsPattern[]
	]:=
	With[{cells=
		StyleSheetCells[nb,cellStyle,
			FilterRules[{ops},
				Options[StyleSheetCells]
				]
			]},
		Replace[cells,{
			c:{__}:>
				StyleSheetValue[c,op,
					FilterRules[{ops},
						Options[StyleSheetCells]
						]
					],
			{}:>
				With[{
					mode=
						Replace[OptionValue["ValueFunction"],{
							Automatic->CurrentValue,
							"Absolute"->AbsoluteCurrentValue
							}]
					},
					Map[
						Replace[
							mode[
								StyleSheetNotebookObject@nb,
								{StyleDefinitions,cellStyle,#}
								],
							$Failed->Inherited
							]&,
						Flatten@{op}
						]
					]
			}]
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetSync*)


Options[StyleSheetSync]=
	DeleteDuplicatesBy[First]@
	Join[
		Options[StyleSheetEdit],
		Options[StyleSheetValue]
		];
StyleSheetSync[
	nb:_NotebookObject|Automatic:Automatic,
	toStyle:$StyleSheetCellStyleSinglePattern,
	fromStyle:$StyleSheetCellStyleSinglePattern,
	op:$StyleSheetCellOptionPatterns:Automatic,
	ops:OptionsPattern[]
	]:=
	With[{
		o=
			Replace[op,Automatic:>$StyleSheetCellDisplayStyleOptions],
		c=
			StyleSheetCells[nb,fromStyle,
				FilterRules[{ops},
					Options[StyleSheetCells]
					]
				]
		},
		StyleSheetEdit[nb,toStyle,
			Thread[
				o->
					If[Length@c>0,	
						StyleSheetValue[First@c,o,
							FilterRules[{ops},
								Options[StyleSheetValue]
								]
							],
						StyleSheetValue[nb,
							fromStyle,
							o,
							FilterRules[{ops},
								Options[StyleSheetValue]
								]
							]
						]
				],
			FilterRules[{ops},
				Options[StyleSheetEdit]
				]
			]
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetDrop*)


StyleSheetDrop[cellObs:_CellObject|{__CellObject},ops__]:=
StyleSheetEdit[cellObs,Sequence@@Thread[{ops}->Inherited]]


Options[StyleSheetDrop]=
	Options[StyleSheetCells];
StyleSheetDrop[
		nb:_NotebookObject|Automatic:Automatic,
		types:$StyleSheetCellStylePatterns:"*",
		op:$StyleSheetCellOptionPatterns,
		ops:OptionsPattern[]
		]:=
	With[{
		cells=
			StyleSheetCells[nb,types,
				FilterRules[{ops},Options[StyleSheetCells]]
				]
			},
		StyleSheetDrop[cells,op,ops]
		];


(* ::Subsubsection::Closed:: *)
(*StyleSheetEditRuleListOption*)


resolveStyleSheetRuleListMergeTag[e_]:=e


resolveStyleSheetRuleListMerge[merge_]:=
	Normal@
		Merge[merge,
			resolveStyleSheetRuleListMergeTag[
				If[OptionQ[#], 
					resolveStyleSheetRuleListMerge[#],
					Last[#]
					]
				]&
			]//.{
				HoldPattern[
					resolveStyleSheetRuleListMergeTag[
						If[_,_,_]
						]&[{___,a_}]
					]:>a,
				HoldPattern[
					resolveStyleSheetRuleListMergeTag[e_]
					]:>e
				}


(* ::Text:: *)
(*This should really be done in terms of CurrentValue but I didn't think to do it initially, so we'll run with it.*)


$StyleSheetRuleListOptionPattern=
	_Rule|_RuleDelayed|{(_Rule|_RuleDelayed)..};


Options[StyleSheetEditRuleListOption]=
	Options[StyleSheetEdit];
StyleSheetEditRuleListOption[
	obs:{__CellObject}|{__NotebookObject},
	op_,
	new:$StyleSheetRuleListOptionPattern
	]:=
	frontEndExecuteBlock[
		Do[
			StyleSheetSetOptions[ob,
				op->
					resolveStyleSheetRuleListMerge@
						Flatten@{
							Replace[op/.Options[ob,op],Except[_List]:>{}],
							new
							}
				],
			{ob,obs}
			];
		StyleSheetApplyEdits[obs];
		];
StyleSheetEditRuleListOption[
	nb:_NotebookObject|Automatic:Automatic,
	cellStyles_,
	op_,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	Replace[
		StyleSheetCells[nb,cellStyles,
			FilterRules[{ops},Options[StyleSheetCells]]
			],{
		c:{__}:>
			StyleSheetEditRuleListOption[c,op,events],
		_->Null
		}];


(* ::Subsubsection::Closed:: *)
(*StyleSheetEditEvents*)


Options[StyleSheetEditEvents]=
	Join[
		Options[StyleSheetEditRuleListOption],
		{
			"EditOption"->Automatic
			}
		];
StyleSheetEditEvents[
	nb:(_NotebookObject|_CellObject|{__CellObject}|Automatic):Automatic,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	With[{
		op=
		Replace[OptionValue["EditOption"],
			Except[CellEventActions|NotebookEventActions|Automatic]->Automatic
			]
		},
		With[{obop=
			Replace[nb,{
				Automatic:>
					{StyleSheetNotebookObject[nb],
						Replace[op,Automatic:>NotebookEventActions]
						},
				_CellObject|{__CellObject}:>
					{nb,
						Replace[op,Automatic:>CellEventActions]
						},
				_NotebookObject:>
					{nb,
						Replace[op,Automatic:>NotebookEventActions]
						}
				}]},
			StyleSheetEditRuleListOption[
				Flatten@{First@obop},
				Last@obop,
				events,
				ops
				]
			]
		];
StyleSheetEditEvents[
	nb:_NotebookObject|Automatic:Automatic,
	cellStyles:$StyleSheetCellStylePatterns,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	Replace[
		StyleSheetCells[nb,cellStyles,FilterRules[{ops},Options[StyleSheetCells]]],{
		c:{__}:>
			StyleSheetEditEvents[c,events,ops],
		_->Null
		}];


(* ::Subsubsection::Closed:: *)
(*StyleSheetEditAliases*)


Options[StyleSheetEditAliases]=
	Options[StyleSheetEditRuleListOption];
StyleSheetEditAliases[
	nb:(_NotebookObject|_CellObject|{__CellObject}|Automatic):Automatic,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	With[{obop=
		Replace[nb,{
			Automatic:>
				{StyleSheetNotebookObject[nb],
					InputAliases
					},
			_CellObject|{__CellObject}:>
				{nb,
					InputAliases
					},
			_NotebookObject:>
				{nb,
					InputAliases
					}
			}]},
		StyleSheetEditRuleListOption[
			Flatten@{First@obop},
			Last@obop,
			events,
			ops
			]
		];
StyleSheetEditAliases[
	nb:_NotebookObject|Automatic:Automatic,
	cellStyles:$StyleSheetCellStylePatterns,
	events:$StyleSheetEventPatterns,
	ops:OptionsPattern[]
	]:=
	Replace[
		StyleSheetCells[nb,cellStyles,FilterRules[{ops},Options[StyleSheetCells]]],{
		c:{__}:>
			StyleSheetEditAliases[c,events,ops],
		_->Null
		}];


(* ::Subsubsection::Closed:: *)
(*StyleSheetEditAutoReplacements*)


Options[StyleSheetEditAutoReplacements]=
	Options[StyleSheetEditRuleListOption];
StyleSheetEditAutoReplacements[
	nb:(_NotebookObject|_CellObject|{__CellObject}|Automatic):Automatic,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	With[{obop=
		Replace[nb,{
			Automatic:>
				{StyleSheetNotebookObject[nb],
					InputAutoReplacements
					},
			_CellObject|{__CellObject}:>
				{nb,
					InputAutoReplacements
					},
			_NotebookObject:>
				{nb,
					InputAutoReplacements
					}
			}]},
		StyleSheetEditRuleListOption[
			Flatten@{First@obop},
			Last@obop,
			events,
			ops
			]
		];
StyleSheetEditAutoReplacements[
	nb:_NotebookObject|Automatic:Automatic,
	cellStyles:$StyleSheetCellStylePatterns,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	Replace[
		StyleSheetCells[nb,cellStyles,FilterRules[{ops},Options[StyleSheetCells]]],{
		c:{__}:>
			StyleSheetEditAutoReplacements[c,events,ops],
		_->Null
		}];


(* ::Subsubsection::Closed:: *)
(*StyleSheetEditTaggingRules*)


Options[StyleSheetEditTaggingRules]=
	Options[StyleSheetEditRuleListOption];
StyleSheetEditTaggingRules[
	nb:(_NotebookObject|_CellObject|{__CellObject}|Automatic):Automatic,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	With[{obop=
		Replace[nb,{
			Automatic:>
				{StyleSheetNotebookObject[nb],
					TaggingRules
					},
			_CellObject|{__CellObject}:>
				{nb,
					TaggingRules
					},
			_NotebookObject:>
				{nb,
					TaggingRules
					}
			}]},
		StyleSheetEditRuleListOption[
			Flatten@{First@obop},
			Last@obop,
			events,
			ops
			]
		];
StyleSheetEditTaggingRules[
	nb:_NotebookObject|Automatic:Automatic,
	cellStyles:$StyleSheetCellStylePatterns,
	events:$StyleSheetRuleListOptionPattern,
	ops:OptionsPattern[]
	]:=
	Replace[
		StyleSheetCells[nb,cellStyles,FilterRules[{ops},Options[StyleSheetCells]]],{
		c:{__}:>
			StyleSheetEditTaggingRules[c,events,ops],
		_->Null
		}];


(* ::Subsection:: *)
(*Autocompletions*)


PackageAddAutocompletions[spec_]:=
	If[$Notebooks&&
		Internal`CachedSystemInformation["FrontEnd","VersionNumber"]>10.0,
		FE`Evaluate[FEPrivate`AddSpecialArgCompletion[spec]],
		$Failed
		];


PackageAddAutocompletions@
	Map[
		#->{"MenuListStyles"}&,
		{
			"StyleSheetEdit",
			"StyleSheetNew",
			"StyleSheetCells",
			"StyleSheetDelete"
			}
		]


(* ::Subsection::Closed:: *)
(*Style Stuff*)


StyleDefinitionsValue[
	bobj:
		$FrontEndSession|_FrontEndObject|_NotebookObject|_CellObject|
			_BoxObject|_FrontEnd`EvaluationNotebook|_FrontEnd`InputNotebook|
			_FrontEnd`EvaluationCell|_FrontEnd`EvaluationBox|_FrontEnd`Self|
			_FrontEnd`ButtonNotebook|_FrontEnd`MessagesNotebook|
			_FrontEnd`ClipboardNotebook|Automatic:Automatic, 
	styles:All|_StringPattern`StringPatternQ:"*", 
	attr_
	]:=
	With[{obj=Replace[bobj, Automatic:>InputNotebook[]]},
		With[
			{
				stills=
					Select[
						Select[Values@FE`Evaluate@FEPrivate`GetPopupList[obj, "MenuListStyles"],
							StringQ
							],
						If[styles===All, True&, StringMatchQ[styles]]
						]},
			AssociationMap[
				CurrentValue[obj, {StyleDefinitions, #, attr}]&,
				stills
				]
			]
		]


(* ::Subsection::Closed:: *)
(*End Private*)


End[];


(* ::Section:: *)
(*End Package*)


EndPackage[]
